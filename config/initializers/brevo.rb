# Brevo (SMTP) delivers invite emails. Test keeps the :test delivery method.
unless Rails.env.test?
  login = ENV["BREVO_SMTP_LOGIN"].to_s.strip
  key = ENV["BREVO_SMTP_KEY"].to_s.strip

  if login.present? && key.present?
    Rails.application.config.action_mailer.delivery_method = :smtp
    Rails.application.config.action_mailer.raise_delivery_errors = true
    Rails.application.config.action_mailer.smtp_settings = {
      address: "smtp-relay.brevo.com",
      # 587 never connects from the server. Brevo accepts the same login on 2525.
      port: 2525,
      user_name: login,
      password: key,
      authentication: :login,
      enable_starttls_auto: true,
      open_timeout: 10,
      read_timeout: 10
    }
  elsif Rails.env.development?
    Rails.application.config.action_mailer.delivery_method = :file
    Rails.application.config.action_mailer.file_settings = { location: Rails.root.join("tmp/mail") }
  elsif Rails.env.production?
    Rails.logger.warn("BREVO_SMTP_LOGIN and BREVO_SMTP_KEY are missing. Invite emails will not be delivered.")
  end
end
