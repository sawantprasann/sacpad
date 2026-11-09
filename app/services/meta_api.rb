require Rails.root.join("lib/meta_credentials")

module MetaApi
  def self.configured? = MetaCredentials.configured?
end
