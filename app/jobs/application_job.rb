class ApplicationJob < ActiveJob::Base
  # Sidekiq retries a failed job. A deadlock or a dropped network call is tried again.
  # discard_on ActiveJob::DeserializationError
end
