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

BRANCH="${1:-main}"

if [[ ! "$BRANCH" =~ ^[A-Za-z0-9][A-Za-z0-9._+/-]*$ ]] || [[ "$BRANCH" == *".."* ]]; then
  echo "=====> [deploy] Invalid branch name: ${BRANCH}" >&2
  exit 1
fi

echo "=====> [deploy] $(date '+%Y-%m-%d %H:%M:%S') Starting deploy of ${BRANCH}"

cd $APP_DIR

echo "=====> [deploy] Fetching origin/${BRANCH}"
git fetch origin "$BRANCH"
git checkout -f -B "$BRANCH" "origin/${BRANCH}"
echo "=====> [deploy] At $(git rev-parse --short HEAD) — $(git log -1 --format=%s)"

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
