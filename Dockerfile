# syntax=docker/dockerfile:1
# check=error=true

# Production image for AWS. Postgres is RDS, not a container.
#   docker build -t sacpad .
#   docker compose up --build
#
# Ruby must match .ruby-version. Thruster listens on 8080 and proxies to Puma
# on 127.0.0.1:3000. No process in this image runs as root.

ARG RUBY_VERSION=3.4.13
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libpq5 \
      libvips && \
    ln -sf "/usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2" /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    BOOTSNAP_CACHE_DIR="/rails/tmp/cache" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true" \
    RUBY_YJIT_ENABLE="1" \
    PORT="3000" \
    HTTP_PORT="8080" \
    TARGET_PORT="3000" \
    STORAGE_PATH="/rails/tmp/thruster" \
    MAX_REQUEST_BODY="209715200" \
    PUMA_BIND="tcp" \
    DB_SSLMODE="verify-full" \
    DB_SSLROOTCERT="/rails/config/certs/rds-global-bundle.pem" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_LOG_LEVEL="info"

FROM base AS build

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler -v 2.7.2 --no-document

COPY Gemfile Gemfile.lock ./

RUN --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    bundle install && \
    rm -rf ~/.bundle \
      "${BUNDLE_PATH}"/ruby/*/cache \
      "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Dummy encryption env is only for this process. It is not kept in the image.
RUN bundle exec bootsnap precompile -j 1 app/ lib/ && \
    SECRET_KEY_BASE_DUMMY=1 \
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=build \
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=build \
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=build \
    ./bin/rails assets:precompile && \
    rm -rf tmp/cache vendor/bundle

FROM base AS runtime

RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin rails && \
    mkdir -p /rails/tmp /rails/log /rails/storage /rails/config/certs && \
    chown -R rails:rails /rails

COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails

# Pinned Amazon RDS global CA bundle. verify-full fails closed if AWS rotates
# this file until RDS_CA_SHA256 is updated on purpose.
ARG RDS_CA_URL=https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
ARG RDS_CA_SHA256=90a6f1a7978a1b1b096dca6c57511ca48d3b8cf052f8e704baf358f34ea2f21b
RUN curl -fsSL "${RDS_CA_URL}" -o /rails/config/certs/rds-global-bundle.pem && \
    echo "${RDS_CA_SHA256}  /rails/config/certs/rds-global-bundle.pem" | sha256sum -c - && \
    chmod 644 /rails/config/certs/rds-global-bundle.pem && \
    chown rails:rails /rails/config/certs/rds-global-bundle.pem && \
    chmod 755 /rails/bin/docker-entrypoint /rails/bin/rails /rails/bin/thrust

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 8080
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${HTTP_PORT}/up" || exit 1

CMD ["./bin/thrust", "./bin/rails", "server"]
