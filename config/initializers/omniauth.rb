require Rails.root.join("lib/meta_credentials")

# Request phase is POST so a cross-site page cannot start Facebook Login.
# The logger stays at warn so the OAuth callback URL (it carries `code`) is not written out.
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
omniauth_logger = ActiveSupport::Logger.new($stdout)
omniauth_logger.level = Logger::WARN
OmniAuth.config.logger = omniauth_logger

app_id = MetaCredentials.app_id
app_secret = MetaCredentials.app_secret

if app_id.present? && app_secret.present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :facebook, app_id, app_secret,
      scope: %w[pages_show_list pages_manage_posts pages_read_engagement pages_read_user_content instagram_basic].join(","),
      info_fields: "name",
      secure_image_url: true
  end
end
