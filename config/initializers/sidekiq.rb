redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    schedule = Rails.root.join("config/sidekiq_schedule.yml")
    next unless schedule.file?

    Sidekiq::Cron::Job.load_from_hash(YAML.safe_load_file(schedule))
  end
end
