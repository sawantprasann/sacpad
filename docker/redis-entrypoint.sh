#!/bin/sh
# Writes a Redis config as the redis user. The password stays in the environment,
# not in the process arguments.
set -e
umask 077

{
  echo "bind 0.0.0.0"
  echo "protected-mode yes"
  echo "port 6379"
  echo "appendonly yes"
  echo "appendfsync everysec"
  echo "maxmemory 256mb"
  echo "maxmemory-policy noeviction"
  echo "rename-command FLUSHALL \"\""
  echo "rename-command FLUSHDB \"\""
  echo "rename-command DEBUG \"\""
  printf 'requirepass %s\n' "$REDIS_PASSWORD"
} > /tmp/redis.conf

exec redis-server /tmp/redis.conf
