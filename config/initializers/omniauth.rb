require Rails.root.join("lib/meta_credentials")
require Rails.root.join("lib/youtube_credentials")
require Rails.root.join("lib/twitter_credentials")

# Request phase is POST so a cross-site page cannot start a login.
# The logger stays at warn so the OAuth callback URL (it carries `code`) is not written out.
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
omniauth_logger = ActiveSupport::Logger.new($stdout)
omniauth_logger.level = Logger::WARN
OmniAuth.config.logger = omniauth_logger

facebook_id = MetaCredentials.app_id
facebook_secret = MetaCredentials.app_secret
youtube_id = YoutubeCredentials.client_id
youtube_secret = YoutubeCredentials.client_secret
twitter_id = TwitterCredentials.client_id
twitter_secret = TwitterCredentials.client_secret
facebook_on = facebook_id.present? && facebook_secret.present?
youtube_on = youtube_id.present? && youtube_secret.present?
twitter_on = twitter_id.present? && twitter_secret.present?

if facebook_on || youtube_on || twitter_on
  Rails.application.config.middleware.use OmniAuth::Builder do
    if facebook_on
      provider :facebook, facebook_id, facebook_secret,
        scope: %w[pages_show_list pages_manage_posts pages_read_engagement pages_read_user_content instagram_basic instagram_content_publish instagram_manage_contents].join(","),
        info_fields: "name",
        secure_image_url: true
    end

    if youtube_on
      provider :google_oauth2, youtube_id, youtube_secret,
        name: "youtube",
        scope: "email profile https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/youtube.upload",
        prompt: "consent"
    end

    if twitter_on
      provider :twitter2, twitter_id, twitter_secret,
        name: "twitter",
        scope: "tweet.read users.read tweet.write offline.access"
    end
  end
end
