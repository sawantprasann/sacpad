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

echo "=====> [deploy] Checking encryption keys"
bin/ensure-encryption-keys
set -a; source .env; set +a

echo "=====> [deploy] Running migrations"
bundle exec rails db:prepare

echo "=====> [deploy] Precompiling assets"
bundle exec rails assets:precompile

echo "=====> [deploy] Restarting Puma"
sudo systemctl restart "puma_${APP_NAME}"

if sudo systemctl cat "sidekiq_${APP_NAME}" >/dev/null 2>&1; then
  echo "=====> [deploy] Restarting Sidekiq"
  sudo systemctl restart "sidekiq_${APP_NAME}"
else
  echo "=====> [deploy] sidekiq_${APP_NAME} is not installed, so jobs will not run"
fi

echo "=====> [deploy] Done"
