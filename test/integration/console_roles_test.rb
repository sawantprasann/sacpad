require "test_helper"

# Story 0.8 — the role editor is Admin-only and creates roles with a module permission matrix.
class ConsoleRolesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123") }

  test "role editor requires admin auth" do
    get "/console/roles"
    assert_redirected_to new_admin_session_path
  end

  test "an admin creates a role with module permissions" do
    sign_in @admin
    assert_difference -> { Role.count }, 1 do
      post "/console/roles", params: {
        role: {
          name: "PR Manager", slug: "pr_manager", can_create_users: "0",
          role_permissions_attributes: {
            "0" => { module_name: "pr", access_level: "write" },
            "1" => { module_name: "voter_lists", access_level: "read" }
          }
        }
      }
    end
    role = Role.find_by(slug: "pr_manager")
    assert_equal "write", role.access_for("pr")
    assert_equal "read", role.access_for("voter_lists")
  end
end
