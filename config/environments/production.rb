require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Nginx terminates TLS for politomatrix.com. Treat proxied requests as HTTPS.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Links in mail, jobs, and Active Storage use the public production host.
  config.action_mailer.default_url_options = { host: "politomatrix.com", protocol: "https" }
  config.action_mailer.asset_host = "https://politomatrix.com"
  config.action_controller.default_url_options = { host: "politomatrix.com", protocol: "https" }

  # Invite mail is delivered by Brevo when BREVO_SMTP_LOGIN and BREVO_SMTP_KEY
  # are set. See config/initializers/brevo.rb.

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Voter ids, names, mobiles, and social tokens are encrypted with these keys.
  # bin/ensure-encryption-keys writes them into .env once. Rotating them makes
  # existing rows unreadable, so a missing key must stop boot rather than fall
  # through to empty credentials.
  missing_encryption_keys = []
  {
    "PRIMARY_KEY" => :primary_key,
    "DETERMINISTIC_KEY" => :deterministic_key,
    "KEY_DERIVATION_SALT" => :key_derivation_salt
  }.each do |suffix, setting|
    env_name = "ACTIVE_RECORD_ENCRYPTION_#{suffix}"
    value = ENV[env_name].to_s.strip
    if value.empty?
      missing_encryption_keys << env_name
    else
      config.active_record.encryption[setting] = value
    end
  end
  if missing_encryption_keys.any?
    raise "Production refuses to boot without #{missing_encryption_keys.join(", ")}. Run bin/ensure-encryption-keys on the server. Do not replace keys that have already encrypted a voter row."
  end

  # Only the public production hosts may reach the app.
  config.hosts = [
    "politomatrix.com",
    "www.politomatrix.com"
  ]
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  config.action_cable.allowed_request_origins = [
    "https://politomatrix.com",
    "https://www.politomatrix.com"
  ]

  config.after_initialize do
    Rails.application.routes.default_url_options = { host: "politomatrix.com", protocol: "https" }
    ActionMailer::Base.default from: ENV["MAIL_FROM"].presence || "Politomatrix <no-reply@politomatrix.com>"
  end
end
