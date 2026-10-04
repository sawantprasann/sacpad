require "test_helper"

# Story 0.12 — Admin manages a specific org's roster; records are org-scoped.
class ConsolePoliticiansTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123")
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Candidate A") }
  end

  test "admin adds a politician scoped to the organization" do
    sign_in @admin
    assert_difference -> { ActsAsTenant.with_tenant(@org) { Politician.count } }, 1 do
      post console_organization_politicians_path(@org),
           params: { politician: { name: "Opponent X", is_own_politician: "0" } }
    end
    pol = ActsAsTenant.with_tenant(@org) { Politician.find_by(name: "Opponent X") }
    assert_equal @org.id, pol.organization_id
  end
end
