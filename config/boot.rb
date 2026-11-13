ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Development reads .env. Test and production do not, so the test suite cannot
# send real mail and the server keeps using its own environment file.
if ENV["RAILS_ENV"].to_s.empty? || ENV["RAILS_ENV"] == "development"
  env_file = File.expand_path("../.env", __dir__)
  if File.file?(env_file)
    File.foreach(env_file) do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      key, value = line.split("=", 2)
      next if key.nil? || key.empty? || ENV.key?(key)
      ENV[key] = value.to_s.strip.gsub(/\A["']|["']\z/, "")
    end
  end
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
