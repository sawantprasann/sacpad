# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# System roles (Story 0.8): org_admin + dreamline_user, seeded idempotently.
Role.seed_system_roles!

# Kitchen Cabinet ticket categories (Story 1.1): the 12 global, Admin-managed categories
# (incl. "Other"), seeded idempotently.
TicketCategory.seed_defaults!

# PR categories (Story 4.1): the 6 fixed PR categories, seeded idempotently.
PrCategory.seed_defaults!

# Bootstrap platform Admin (Story 0.3) — the only way into the Console (no self-service sign-up).
# Configurable via env; in production a password MUST be provided (no insecure default).
admin_email = ENV.fetch("SACPAD_ADMIN_EMAIL", "admin@sacpad.com")
admin_password = ENV["SACPAD_ADMIN_PASSWORD"] || (Rails.env.production? ? nil : "password123")

if admin_password
  admin = Admin.find_or_create_by!(email: admin_email) do |a|
    a.name = "Platform Admin"
    a.tier = :full
    a.password = admin_password
  end
  puts "Seeded platform Admin: #{admin.email} (#{admin.tier} tier)" unless Rails.env.production?
else
  warn "Skipping Admin seed — set SACPAD_ADMIN_PASSWORD to seed a platform Admin in production."
end
