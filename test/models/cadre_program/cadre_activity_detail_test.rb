require "test_helper"
require_relative "../../support/tenant_isolation"

module CadreProgram
  # Story 2.2 — each category persists its own detail row. Two categories share CadreActivityProgram.
  class CadreActivityDetailTest < ActiveSupport::TestCase
    include TenantIsolation

    setup do
      ActsAsTenant.without_tenant do
        @org_a = Organization.create!(name: "Detail Org A")
        @org_b = Organization.create!(name: "Detail Org B")
        @role = Role.create!(name: "Detail Field", slug: "detail-field")
        @user_a = User.create!(organization: @org_a, role: @role, name: "Asha", email: "detail-a@example.com", password: "password123")
        @user_b = User.create!(organization: @org_b, role: @role, name: "Bima", email: "detail-b@example.com", password: "password123")
        @foreign_program = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :program_by_party,
          program_attributes: { program_name: "Their program" }
        ).program
      end
    end

    test "program by party and personal program share one detail class" do
      ActsAsTenant.with_tenant(@org_a) do
        party = CadreActivity.create!(owner: @user_a, category: :program_by_party, program_attributes: { program_name: "Party day", host: "Taluka" })
        personal = CadreActivity.create!(owner: @user_a, category: :personal_program, program_attributes: { program_name: "Home visit" })
        assert_instance_of CadreActivityProgram, party.program
        assert_instance_of CadreActivityProgram, personal.program
        assert_equal "Taluka", party.program.host
        assert_not_equal party.program.id, personal.program.id
      end
    end

    test "the other categories create their own detail row and ignore a mismatched shape" do
      ActsAsTenant.with_tenant(@org_a) do
        meet = CadreActivity.create!(
          owner: @user_a, category: :leadership_meets,
          leadership_meet_attributes: { whom_to_meet: "MLA" },
          program_attributes: { program_name: "Should be dropped" }
        )
        hosted = CadreActivity.create!(owner: @user_a, category: :party_programs_hosted, party_program_hosted_attributes: { program_name: "Andolan", total_attendees: 40 })
        personal = CadreActivity.create!(owner: @user_a, category: :personal_activities, personal_activity_attributes: { activity_name: "Camp" })

        assert_equal "MLA", meet.leadership_meet.whom_to_meet
        assert_nil meet.program
        assert_equal 40, hosted.party_program_hosted.total_attendees
        assert_equal "Camp", personal.personal_activity.activity_name
      end
    end

    test "one to one accepts a same-org user or a fallback name, and rejects another org" do
      ActsAsTenant.with_tenant(@org_a) do
        named = CadreActivity.create!(owner: @user_a, category: :one_to_one, one_to_one_attributes: { karyakarta_name_text: "Sita" })
        assert_equal "Sita", named.one_to_one.karyakarta_name_text
        assert_nil named.one_to_one.karyakarta_user
        assert_not named.one_to_one.resolved?

        linked = CadreActivity.create!(owner: @user_a, category: :one_to_one, one_to_one_attributes: { karyakarta_user_id: @user_a.id, resolved: true })
        assert_equal @user_a, linked.one_to_one.karyakarta_user

        missing = CadreActivity.new(owner: @user_a, category: :one_to_one, one_to_one_attributes: { assignment: "Booth" })
        assert_not missing.valid?

        cross = CadreActivity.new(owner: @user_a, category: :one_to_one, one_to_one_attributes: { karyakarta_user_id: @user_b.id })
        assert_not cross.valid?
        assert cross.one_to_one.errors[:karyakarta_user].any?
      end
    end

    test "a category without its detail does not save" do
      ActsAsTenant.with_tenant(@org_a) do
        activity = CadreActivity.new(owner: @user_a, category: :leadership_meets, impact_notes: "No names")
        assert_not activity.valid?
        assert_match(/Leadership Meets/, activity.errors.full_messages.to_sentence)
      end
    end

    test "detail models raise with no tenant and stay inside their organization" do
      foreign = {}
      ActsAsTenant.without_tenant do
        foreign[:meet] = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :leadership_meets,
          leadership_meet_attributes: { whom_to_meet: "Their MLA" }
        ).leadership_meet
        foreign[:hosted] = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :party_programs_hosted,
          party_program_hosted_attributes: { program_name: "Their andolan" }
        ).party_program_hosted
        foreign[:personal] = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :personal_activities,
          personal_activity_attributes: { activity_name: "Their camp" }
        ).personal_activity
        foreign[:one] = CadreActivity.create!(
          organization: @org_b, owner: @user_b, category: :one_to_one,
          one_to_one_attributes: { karyakarta_name_text: "Their Sita" }
        ).one_to_one
      end

      {
        CadreActivityProgram => @foreign_program,
        CadreActivityLeadershipMeet => foreign[:meet],
        CadreActivityPartyProgramHosted => foreign[:hosted],
        CadreActivityPersonalActivity => foreign[:personal],
        CadreActivityOneToOne => foreign[:one]
      }.each do |model, record|
        assert_raises_without_tenant(model)
        assert_tenant_isolated(model, owner: @org_a, foreign_record: record)
      end
    end
  end
end
