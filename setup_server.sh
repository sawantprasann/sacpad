#!/bin/bash
# =============================================================================
# SAC-PAD — DigitalOcean server setup
# Run once as root on a fresh Ubuntu 24.04 droplet:
#   bash setup_server.sh
# Server IP: 143.110.248.201
# =============================================================================

set -euo pipefail

APP_NAME="sacpad"
DEPLOY_USER="deploy"
APP_DIR="/var/www/$APP_NAME"
RUBY_VERSION="3.4.6"
REPO_URL="git@github.com:sawantprasann/sacpad.git"
SERVER_IP="143.110.248.201"
DB_PASSWORD_FILE="/root/.sacpad_db_password"
ADMIN_PASSWORD_FILE="/root/.sacpad_admin_password"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: bash setup_server.sh"
  exit 1
fi

# =============================================================================
echo "=====> [1/11] System update + dependencies"
# =============================================================================
apt-get update -y && apt-get upgrade -y
apt-get install -y \
  git curl wget gnupg2 software-properties-common \
  build-essential libssl-dev libreadline-dev zlib1g-dev \
  libpq-dev libffi-dev libyaml-dev \
  autoconf bison patch \
  libgdbm6 libgdbm-dev libgdbm-compat-dev libdb-dev uuid-dev \
  nginx postgresql postgresql-contrib \
  libvips42 \
  ufw

systemctl enable --now postgresql
systemctl enable --now nginx

# =============================================================================
echo "=====> [2/11] Add 2GB swap (prevents OOM during Ruby compile)"
# =============================================================================
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo ">>> Swap created."
else
  echo ">>> Swap already exists, skipping."
fi

# =============================================================================
echo "=====> [3/11] Create deploy user"
# =============================================================================
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" $DEPLOY_USER
fi
usermod -aG sudo $DEPLOY_USER

# Nginx (www-data) must connect to the Puma socket owned by deploy.
usermod -aG $DEPLOY_USER www-data

echo "$DEPLOY_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart puma_$APP_NAME, /bin/systemctl start puma_$APP_NAME, /bin/systemctl stop puma_$APP_NAME, /bin/systemctl status puma_$APP_NAME" \
  > /etc/sudoers.d/$DEPLOY_USER
chmod 0440 /etc/sudoers.d/$DEPLOY_USER

# =============================================================================
echo "=====> [4/11] Install rbenv + Ruby $RUBY_VERSION (as deploy user)"
# =============================================================================
# Must use 'su - deploy' (not sudo -u) to avoid rbenv path issues
su - $DEPLOY_USER <<RUBY_SETUP
  set -euo pipefail

  if [ ! -d "\$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git \$HOME/.rbenv
    git clone https://github.com/rbenv/ruby-build.git \$HOME/.rbenv/plugins/ruby-build
  fi

  grep -qxF 'export PATH="\$HOME/.rbenv/bin:\$PATH"' \$HOME/.bashrc || echo 'export PATH="\$HOME/.rbenv/bin:\$PATH"' >> \$HOME/.bashrc
  grep -qxF 'eval "\$(rbenv init -)"' \$HOME/.bashrc || echo 'eval "\$(rbenv init -)"' >> \$HOME/.bashrc

  export PATH="\$HOME/.rbenv/bin:\$PATH"
  eval "\$(rbenv init -)"

  # Disable YJIT so Ruby does not need a Rust compile on a small droplet.
  RUBY_CONFIGURE_OPTS="--disable-yjit" rbenv install -s $RUBY_VERSION
  rbenv global $RUBY_VERSION

  gem install bundler -v 2.7.2 --no-document
RUBY_SETUP

# =============================================================================
echo "=====> [5/11] Configure PostgreSQL"
# =============================================================================
if [ ! -f "$DB_PASSWORD_FILE" ]; then
  openssl rand -hex 24 > "$DB_PASSWORD_FILE"
  chmod 600 "$DB_PASSWORD_FILE"
fi
DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"

sudo -u postgres psql <<PSQL
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$APP_NAME') THEN
      CREATE USER $APP_NAME WITH PASSWORD '${DB_PASSWORD}';
    END IF;
  END \$\$;
  SELECT 'CREATE DATABASE ${APP_NAME}_production OWNER $APP_NAME'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_production')\gexec
  SELECT 'CREATE DATABASE ${APP_NAME}_production_cache OWNER $APP_NAME'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_production_cache')\gexec
  SELECT 'CREATE DATABASE ${APP_NAME}_production_queue OWNER $APP_NAME'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_production_queue')\gexec
  SELECT 'CREATE DATABASE ${APP_NAME}_production_cable OWNER $APP_NAME'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_NAME}_production_cable')\gexec
PSQL

echo ">>> PostgreSQL user '$APP_NAME' and production databases are ready."

# =============================================================================
echo "=====> [6/11] Set up app directory + clone repo"
# =============================================================================
mkdir -p $APP_DIR
chown -R $DEPLOY_USER:$DEPLOY_USER $APP_DIR

mkdir -p /home/$DEPLOY_USER/.ssh
chmod 700 /home/$DEPLOY_USER/.ssh
chown $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh

if [ ! -f /home/$DEPLOY_USER/.ssh/id_ed25519 ]; then
  sudo -u $DEPLOY_USER ssh-keygen -t ed25519 -f /home/$DEPLOY_USER/.ssh/id_ed25519 -N ""
fi

# Same key lets the server git pull, and GitHub Actions SSH in as deploy.
touch /home/$DEPLOY_USER/.ssh/authorized_keys
grep -qxF "$(cat /home/$DEPLOY_USER/.ssh/id_ed25519.pub)" /home/$DEPLOY_USER/.ssh/authorized_keys \
  || cat /home/$DEPLOY_USER/.ssh/id_ed25519.pub >> /home/$DEPLOY_USER/.ssh/authorized_keys
chmod 700 /home/$DEPLOY_USER/.ssh
chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/id_ed25519
chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh

if [ ! -d "$APP_DIR/.git" ]; then
  echo ""
  echo ">>> Deploy public key (add this to GitHub → repo → Settings → Deploy keys, read-only):"
  cat /home/$DEPLOY_USER/.ssh/id_ed25519.pub
  echo ""
  echo ">>> Press Enter after adding the key to GitHub..."
  read -r
fi

su - $DEPLOY_USER <<CLONE
  set -euo pipefail
  export PATH="\$HOME/.rbenv/bin:\$PATH"
  eval "\$(rbenv init -)"

  mkdir -p \$HOME/.ssh
  ssh-keyscan github.com >> \$HOME/.ssh/known_hosts 2>/dev/null

  if [ ! -d "$APP_DIR/.git" ]; then
    git clone $REPO_URL $APP_DIR
  else
    echo ">>> Repo already cloned, skipping."
  fi
CLONE

# =============================================================================
echo "=====> [7/11] Create .env file"
# =============================================================================
if [ ! -s "$APP_DIR/config/master.key" ]; then
  if [ -z "${RAILS_MASTER_KEY:-}" ]; then
    echo "Paste the contents of config/master.key from your laptop, then press Enter:"
    read -r RAILS_MASTER_KEY
  fi
  if [ -z "${RAILS_MASTER_KEY:-}" ]; then
    echo "RAILS_MASTER_KEY is required so Rails can decrypt credentials."
    exit 1
  fi
  printf '%s\n' "$RAILS_MASTER_KEY" > "$APP_DIR/config/master.key"
  chown $DEPLOY_USER:$DEPLOY_USER "$APP_DIR/config/master.key"
  chmod 600 "$APP_DIR/config/master.key"
fi
RAILS_MASTER_KEY="$(tr -d '[:space:]' < "$APP_DIR/config/master.key")"

if [ ! -f "$ADMIN_PASSWORD_FILE" ]; then
  openssl rand -hex 12 > "$ADMIN_PASSWORD_FILE"
  chmod 600 "$ADMIN_PASSWORD_FILE"
fi
ADMIN_PASSWORD="$(cat "$ADMIN_PASSWORD_FILE")"
ADMIN_EMAIL="admin@sacpad.com"

ENV_FILE="$APP_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  cat > $ENV_FILE <<ENV
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

DB_HOST=localhost
SACPAD_DATABASE_PASSWORD=${DB_PASSWORD}

# Solid Queue runs inside Puma on this single server.
SOLID_QUEUE_IN_PUMA=true

SACPAD_ADMIN_EMAIL=${ADMIN_EMAIL}
SACPAD_ADMIN_PASSWORD=${ADMIN_PASSWORD}
ENV
  chown $DEPLOY_USER:$DEPLOY_USER $ENV_FILE
  chmod 600 $ENV_FILE
  echo ">>> .env created."
else
  echo ">>> .env already exists, skipping."
fi

# =============================================================================
echo "=====> [8/11] Bundle install + db prepare + assets + seed"
# =============================================================================
mkdir -p "$APP_DIR/tmp/pids" "$APP_DIR/tmp/storage" "$APP_DIR/storage" "$APP_DIR/log"
chown -R $DEPLOY_USER:$DEPLOY_USER "$APP_DIR"

su - $DEPLOY_USER <<BUNDLE
  set -euo pipefail
  export PATH="\$HOME/.rbenv/bin:\$PATH"
  eval "\$(rbenv init -)"
  cd $APP_DIR
  set -a; source .env; set +a

  bundle config set deployment true
  bundle config set without 'development test'
  bundle install
  bundle exec rails db:prepare
  bundle exec rails assets:precompile
  bundle exec rails db:seed
BUNDLE

# =============================================================================
echo "=====> [9/11] Create Puma systemd service"
# =============================================================================
cat > /etc/systemd/system/puma_${APP_NAME}.service <<SERVICE
[Unit]
Description=Puma HTTP Server — $APP_NAME
After=network.target postgresql.service

[Service]
Type=simple
User=$DEPLOY_USER
Group=$DEPLOY_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
# Socket must be group-writable so www-data (in the deploy group) can connect.
UMask=0007
ExecStart=/home/$DEPLOY_USER/.rbenv/shims/bundle exec puma -C $APP_DIR/config/puma.rb
ExecReload=/bin/kill -SIGUSR1 \$MAINPID
Restart=always
RestartSec=5
StandardOutput=append:/var/log/puma_${APP_NAME}.log
StandardError=append:/var/log/puma_${APP_NAME}.log

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable puma_${APP_NAME}
systemctl restart puma_${APP_NAME}

puma_ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if systemctl is-active --quiet puma_${APP_NAME}; then
    puma_ready=1
    break
  fi
  sleep 5
done
systemctl status puma_${APP_NAME} --no-pager || true
if [ "$puma_ready" -ne 1 ]; then
  echo "Puma did not stay up. See /var/log/puma_${APP_NAME}.log"
  exit 1
fi

# =============================================================================
echo "=====> [10/11] Configure Nginx"
# =============================================================================
cat > /etc/nginx/sites-available/$APP_NAME <<NGINX
upstream puma_${APP_NAME} {
  server unix:$APP_DIR/tmp/puma.sock fail_timeout=0;
}

server {
  listen 80;
  server_name ${SERVER_IP};

  root $APP_DIR/public;
  access_log /var/log/nginx/${APP_NAME}_access.log;
  error_log  /var/log/nginx/${APP_NAME}_error.log;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  location / {
    try_files \$uri/index.html \$uri @puma;
  }

  location @puma {
    proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header  X-Forwarded-Proto \$scheme;
    proxy_set_header  Host \$http_host;
    proxy_redirect    off;
    proxy_pass        http://puma_${APP_NAME};
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 100M;
  keepalive_timeout 10;
}
NGINX

ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/$APP_NAME
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# =============================================================================
echo "=====> [11/11] Configure firewall"
# =============================================================================
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# =============================================================================
echo ""
echo "======================================================"
echo " Setup complete!"
echo "======================================================"
echo ""
echo " App:     http://${SERVER_IP}"
echo " Health:  curl http://${SERVER_IP}/up"
echo ""
echo " Platform admin (change this password after first login):"
echo "   email:    ${ADMIN_EMAIL}"
echo "   password: ${ADMIN_PASSWORD}"
echo ""
echo " Next steps:"
echo "   1. Add the deploy private key to GitHub → repo → Settings → Secrets → Actions"
echo "      Name: DO_SSH_PRIVATE_KEY"
echo "      Value:"
echo "      cat /home/$DEPLOY_USER/.ssh/id_ed25519"
echo "   2. Merge to main to run tests and deploy"
echo "   3. (Optional) Point a domain at ${SERVER_IP}, then run:"
echo "      certbot --nginx -d yourdomain.com"
echo ""
