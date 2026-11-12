#!/bin/bash
# =============================================================================
# SAC-PAD — Deploy script
# Runs on the server during each GitHub Actions deploy.
# Location on server: /var/www/sacpad/deploy.sh
# =============================================================================

set -euo pipefail

APP_DIR="/var/www/sacpad"
APP_NAME="sacpad"

export PATH="/home/deploy/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

echo "=====> [deploy] $(date '+%Y-%m-%d %H:%M:%S') Starting deploy"

cd $APP_DIR

echo "=====> [deploy] Pulling latest code"
git pull --ff-only origin main

echo "=====> [deploy] Installing gems"
bundle config set deployment true
bundle config set without 'development test'
bundle install

set -a; source .env; set +a

echo "=====> [deploy] Running migrations"
bundle exec rails db:prepare

echo "=====> [deploy] Precompiling assets"
bundle exec rails assets:precompile

echo "=====> [deploy] Restarting Puma"
# Hot restart keeps the socket open. A full stop drops it and every open request returns 500.
if bundle exec pumactl -S "$APP_DIR/tmp/pids/server.state" restart; then
  echo "=====> [deploy] Puma reloaded without dropping connections"
else
  echo "=====> [deploy] Reload failed, restarting the service"
  sudo systemctl restart "puma_${APP_NAME}"
fi

echo "=====> [deploy] Done"
