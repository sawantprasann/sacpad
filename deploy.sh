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
sudo systemctl restart puma_${APP_NAME}

echo "=====> [deploy] Done"
