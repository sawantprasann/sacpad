require "test_helper"
require_relative "../../support/tenant_isolation"

module CadreProgram
  # Story 2.1 — CadreActivity is the org-scoped base row for cadre work. The per-model
  # isolation test is a release blocker (FR11).
  class CadreActivityTest < ActiveSupport::TestCase
    include TenantIsolation

    setup do
      ActsAsTenant.without_tenant do
        @org_a = Organization.create!(name: "Org A")
        @org_b = Organization.create!(name: "Org B")
        @role  = Role.create!(name: "Field", slug: "field-cadre")
        @user_a = User.create!(organization: @org_a, role: @role, name: "A", email: "cadre-a@example.com", password: "password123")
        @user_b = User.create!(organization: @org_b, role: @role, name: "B", email: "cadre-b@example.com", password: "password123")
        @b_activity = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :leadership_meets,
          leadership_meet_attributes: { whom_to_meet: "Sarpanch" }
        )
      end
    end

    test "is org-scoped domain data with soft delete" do
      assert_includes CadreActivity.ancestors, OrganizationScoped
      assert_includes CadreActivity.ancestors, SoftDeletable
      assert_not_includes CadreActivity.ancestors, FullyVersioned
      assert_equal "cadre_activities", CadreActivity.table_name
    end

    test "category is a fixed six-value integer enum" do
      assert_equal 0, CadreActivity.categories[:program_by_party]
      assert_equal 1, CadreActivity.categories[:leadership_meets]
      assert_equal 2, CadreActivity.categories[:party_programs_hosted]
      assert_equal 3, CadreActivity.categories[:personal_program]
      assert_equal 4, CadreActivity.categories[:personal_activities]
      assert_equal 5, CadreActivity.categories[:one_to_one]
      assert_equal 6, CadreActivity.categories.size
    end

    test "category labels are the product names, not humanized keys" do
      assert_equal "Program By Party", CadreActivity::CATEGORY_LABELS["program_by_party"]
      assert_equal "One To One", CadreActivity::CATEGORY_LABELS["one_to_one"]
      assert_equal 6, CadreActivity::CATEGORY_LABELS.size
    end

    test "category is required and media value plus photos are optional" do
      ActsAsTenant.with_tenant(@org_a) do
        blank = CadreActivity.new(owner: @user_a)
        assert_not blank.valid?
        assert blank.errors[:category].any?

        saved = CadreActivity.create!(
          owner: @user_a, category: :one_to_one,
          one_to_one_attributes: { karyakarta_name_text: "Sita" }
        )
        assert_nil saved.impact_notes
        assert_not saved.photos.attached?

        noted = CadreActivity.create!(
          owner: @user_a, category: :program_by_party, impact_notes: "Warm local reaction",
          program_attributes: { program_name: "Booth meeting" }
        )
        noted.photos.attach(io: File.open(file_fixture("photo.png")), filename: "photo.png", content_type: "image/png")
        assert noted.photos.attached?
        assert_equal "Warm local reaction", noted.impact_notes
      end
    end

    test "a query with no tenant set raises" do
      assert_raises_without_tenant(CadreActivity)
    end

    test "Org A cannot read, update, or delete an Org B activity" do
      assert_tenant_isolated(CadreActivity, owner: @org_a, foreign_record: @b_activity)
    end
  end
end
