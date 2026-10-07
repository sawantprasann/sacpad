# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Chartkick ships chartkick.js and Chart.js for Sprockets. Propshaft does not
# pick up that vendor folder on its own, so the pie charts stay on "Loading...".
Rails.application.config.assets.paths << Chartkick::Engine.root.join("vendor/assets/javascripts")
