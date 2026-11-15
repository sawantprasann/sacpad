# Uploads go to S3 when the bucket and keys are set. Test keeps the local disk service.
unless Rails.env.test?
  ready = %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_S3_BUCKET].all? { |key| ENV[key].present? }

  if ready
    Rails.application.config.active_storage.service = :amazon
  elsif Rails.env.production?
    Rails.logger.warn("AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_S3_BUCKET are missing. Uploads stay on local disk.")
  end
end
