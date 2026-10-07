require "test_helper"

class GroundReports::GroundReportTest < ActiveSupport::TestCase
  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }
    state = State.create!(name: "Maharashtra")
    loksabha = state.loksabhas.create!(name: "Baramati")
    @assembly = loksabha.assemblies.create!(name: "Indapur")
    @elsewhere = loksabha.assemblies.create!(name: "Elsewhere")
    @village = @assembly.villages.create!(name: "Nimgaon")
    @outside = @elsewhere.villages.create!(name: "Far")
    @org.update!(constituency: @assembly)
    @other.update!(constituency: @elsewhere)

    role = Role.create!(name: "Field", slug: "gr-field")
    @user = User.create!(organization: @org, role: role, name: "Rohan", email: "gr-model@example.com", password: "password123")
  end

  test "a report accepts a text testimonial and rejects audio without a file" do
    ActsAsTenant.with_tenant(@org) do
      report = GroundReports::GroundReport.new(
        owner: @user, village: @village, issue_text: "Water shortage", reported_at: Date.current,
        testimonials_attributes: [
          { person_name: "Asha", content_type: "text", text_content: "The well is dry" }
        ]
      )
      assert report.save, report.errors.full_messages.to_sentence
      assert_equal 1, report.testimonials.count
      assert_equal @org, report.testimonials.first.organization

      audio = report.testimonials.new(person_name: "Ravi", content_type: "audio", created_by: @user)
      assert_not audio.save
      assert audio.errors[:media].any?
    end
  end

  test "a village outside the constituency is rejected" do
    ActsAsTenant.with_tenant(@org) do
      report = GroundReports::GroundReport.new(
        owner: @user, village: @outside, issue_text: "Road", reported_at: Date.current
      )
      assert_not report.save
      assert report.errors[:village].any?
    end
  end

  test "another organization can report the same village name in its own constituency" do
    role = Role.create!(name: "Other", slug: "gr-other")
    other_user = ActsAsTenant.without_tenant do
      User.create!(organization: @other, role: role, name: "Zed", email: "gr-other@example.com", password: "password123")
    end
    ActsAsTenant.with_tenant(@other) do
      report = GroundReports::GroundReport.create!(
        owner: other_user, village: @outside, issue_text: "Clinic", reported_at: Date.current
      )
      assert_equal @other, report.organization
    end
    ActsAsTenant.with_tenant(@org) do
      assert_equal 0, GroundReports::GroundReport.count
    end
  end
end
