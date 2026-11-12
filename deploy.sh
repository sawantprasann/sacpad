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
# Phased restart keeps the old process answering until the new one is ready.
# The first deploy after turning workers on cannot do that, so it falls back to a full restart.
if bundle exec pumactl -S "$APP_DIR/tmp/pids/server.state" phased-restart; then
  echo "=====> [deploy] Puma reloaded without dropping connections"
else
  echo "=====> [deploy] Phased reload unavailable, restarting the service"
  sudo systemctl restart "puma_${APP_NAME}"
fi

echo "=====> [deploy] Done"
