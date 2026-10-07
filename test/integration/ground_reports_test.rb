require "test_helper"

# Story 3.1 — village report with text/audio/video testimonials, constituency and subtree scoped.
class GroundReportsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    state = State.create!(name: "Maharashtra")
    loksabha = state.loksabhas.create!(name: "Baramati")
    assembly = loksabha.assemblies.create!(name: "Indapur")
    @village = assembly.villages.create!(name: "Nimgaon")
    @outside = loksabha.assemblies.create!(name: "Elsewhere").villages.create!(name: "Far")
    @org.update!(constituency: assembly)

    @write = Role.create!(name: "Field", slug: "gr-write")
    @write.role_permissions.create!(module_name: "ground_reports", access_level: "write")
    @read = Role.create!(name: "Viewer", slug: "gr-read")
    @read.role_permissions.create!(module_name: "ground_reports", access_level: "read")
    @none = Role.create!(name: "Outsider", slug: "gr-none")

    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "gr-alice@example.com", password: "password123")
    @bob = User.create!(organization: @org, role: @write, name: "Bob", email: "gr-bob@example.com", password: "password123")
  end

  test "a writer sees constituency villages and can log a report with a text testimonial" do
    sign_in @alice
    get ground_reports_villages_path
    assert_response :success
    assert_match "Nimgaon", @response.body
    assert_no_match(/Far/, @response.body)
    assert_select "a[href=?]", ground_reports_village_path(@village)

    assert_difference -> { GroundReports::GroundReport.unscoped.count }, 1 do
      post ground_reports_village_reports_path(@village), params: { ground_report: {
        issue_text: "Water shortage", resolution_text: "Tanker arranged", reported_at: Date.current,
        organization_id: 0,
        testimonials_attributes: {
          "0" => { person_name: "Asha", content_type: "text", text_content: "The well is dry" }
        }
      } }
    end
    report = GroundReports::GroundReport.unscoped.order(:id).last
    assert_redirected_to ground_reports_village_report_path(@village, report)
    assert_equal @org, report.organization
    assert_equal @alice, report.owner
    ActsAsTenant.with_tenant(@org) do
      assert_equal "The well is dry", report.testimonials.first.text_content
    end

    get ground_reports_village_report_path(@village, report)
    assert_response :success
    assert_match "Asha", @response.body
    assert_select "nav[aria-label=Breadcrumb] a", text: "Ground Reports"
  end

  test "audio testimonials store the file" do
    sign_in @alice
    post ground_reports_village_reports_path(@village), params: { ground_report: {
      issue_text: "Clinic", reported_at: Date.current,
      testimonials_attributes: {
        "0" => { person_name: "Ravi", content_type: "audio", media: fixture_file_upload("photo.png", "audio/mpeg") }
      }
    } }
    report = GroundReports::GroundReport.unscoped.order(:id).last
    ActsAsTenant.with_tenant(@org) do
      assert report.testimonials.first.media.attached?
    end
  end

  test "a peer's report and a village outside the constituency are hidden" do
    report = ActsAsTenant.with_tenant(@org) do
      GroundReports::GroundReport.create!(owner: @bob, village: @village, issue_text: "Peer issue", reported_at: Date.current)
    end
    sign_in @alice
    get ground_reports_village_path(@village)
    assert_no_match(/Peer issue/, @response.body)
    get ground_reports_village_report_path(@village, report)
    assert_response :not_found

    get ground_reports_village_path(@outside)
    assert_response :not_found
  end

  test "a read-only user can browse but cannot create; no access redirects" do
    reader = User.create!(organization: @org, role: @read, name: "Nisha", email: "gr-nisha@example.com", password: "password123")
    sign_in reader
    get ground_reports_villages_path
    assert_response :success
    post ground_reports_village_reports_path(@village), params: { ground_report: { issue_text: "Nope" } }
    assert_response :not_found

    outsider = User.create!(organization: @org, role: @none, name: "Out", email: "gr-out@example.com", password: "password123")
    sign_in outsider
    get ground_reports_villages_path
    assert_redirected_to root_path
  end

  test "a writer maintains worship places, the yatra note, and political history" do
    party = Party.create!(name: "Sample Party")
    sign_in @alice
    get ground_reports_village_path(@village)
    assert_response :success
    assert_match "Worship places", @response.body
    assert_select "button", text: "Add place"

    assert_difference -> { GroundReports::WorshipPlace.unscoped.count }, 1 do
      post ground_reports_village_worship_places_path(@village), params: { worship_place: {
        name: "Jama Masjid", place_type: "Mosque", notes: "Friday prayers", organization_id: 0
      } }
    end
    place = GroundReports::WorshipPlace.unscoped.order(:id).last
    assert_redirected_to ground_reports_village_path(@village)
    assert_equal @org, place.organization
    assert_equal "Mosque", place.place_type

    patch ground_reports_village_yatra_path(@village), params: { village_yatra: { notes: "First walk" } }
    patch ground_reports_village_yatra_path(@village), params: { village_yatra: { notes: "Updated walk" } }
    yatras = GroundReports::VillageYatra.unscoped.where(village: @village, organization: @org)
    assert_equal 1, yatras.count
    assert_equal "Updated walk", yatras.first.notes
    assert_equal @alice, yatras.first.updated_by

    post ground_reports_village_political_positions_path(@village), params: { village_political_position: {
      party_id: party.id, representative_name: "Old", position_title: "Sarpanch", started_at: "2020-01-01"
    } }
    post ground_reports_village_political_positions_path(@village), params: { village_political_position: {
      party_id: party.id, representative_name: "New", position_title: "Sarpanch", started_at: "2024-06-01"
    } }
    positions = GroundReports::VillagePoliticalPosition.unscoped.where(village: @village, organization: @org)
    assert_equal Date.new(2024, 6, 1), positions.find_by!(representative_name: "Old").ended_at
    assert_nil positions.find_by!(representative_name: "New").ended_at

    get ground_reports_village_path(@village)
    assert_match "Jama Masjid", @response.body
    assert_match "Updated walk", @response.body
    assert_match "Current", @response.body

    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::WorshipPlace.create!(village: @village, name: "Secret Shrine", place_type: "Temple")
    end
    get ground_reports_village_path(@village)
    assert_no_match(/Secret Shrine/, @response.body)

    post ground_reports_village_worship_places_path(@outside), params: { worship_place: {
      name: "Nope", place_type: "Temple"
    } }
    assert_response :not_found
  end

  test "a read-only user sees village facts and cannot change them" do
    ActsAsTenant.with_tenant(@org) do
      GroundReports::WorshipPlace.create!(village: @village, name: "Jama Masjid", place_type: "Mosque")
    end
    reader = User.create!(organization: @org, role: @read, name: "Nisha", email: "gr-facts-read@example.com", password: "password123")
    sign_in reader
    get ground_reports_village_path(@village)
    assert_response :success
    assert_match "Jama Masjid", @response.body
    assert_select "button", text: "Add place", count: 0

    post ground_reports_village_worship_places_path(@village), params: { worship_place: {
      name: "Nope", place_type: "Temple"
    } }
    assert_response :not_found
  end

  test "a writer adds local contacts without creating logins" do
    sign_in @alice
    get ground_reports_village_path(@village)
    assert_select "button", text: "Add karyakarta"

    assert_no_difference -> { User.count } do
      assert_difference -> { GroundReports::VillageLocalKaryakarta.unscoped.count }, 1 do
        post ground_reports_village_local_karyakartas_path(@village), params: { village_local_karyakarta: {
          name: "Asha", phone: "9876543210", notes: "Booth 3", organization_id: 0
        } }
      end
      assert_difference -> { GroundReports::VillageLocalAdminContact.unscoped.count }, 1 do
        post ground_reports_village_local_admin_contacts_path(@village), params: { village_local_admin_contact: {
          name: "Ramesh", role_title: "Gram Sevak", phone: "9123456780", organization_id: 0
        } }
      end
    end
    karyakarta = GroundReports::VillageLocalKaryakarta.unscoped.order(:id).last
    contact = GroundReports::VillageLocalAdminContact.unscoped.order(:id).last
    assert_equal @org, karyakarta.organization
    assert_equal "Gram Sevak", contact.role_title
    assert_equal @org, contact.organization

    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org C", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::VillageLocalKaryakarta.create!(village: @village, name: "Hidden Worker")
    end
    get ground_reports_village_path(@village)
    assert_match "Asha", @response.body
    assert_match "Gram Sevak", @response.body
    assert_no_match(/Hidden Worker/, @response.body)

    post ground_reports_village_local_karyakartas_path(@outside), params: { village_local_karyakarta: {
      name: "Nope"
    } }
    assert_response :not_found
  end

  test "a read-only user sees local contacts and cannot add them" do
    ActsAsTenant.with_tenant(@org) do
      GroundReports::VillageLocalKaryakarta.create!(village: @village, name: "Asha", phone: "9876543210")
    end
    reader = User.create!(organization: @org, role: @read, name: "Meera", email: "gr-contacts-read@example.com", password: "password123")
    sign_in reader
    get ground_reports_village_path(@village)
    assert_match "Asha", @response.body
    assert_select "button", text: "Add karyakarta", count: 0

    post ground_reports_village_local_karyakartas_path(@village), params: { village_local_karyakarta: { name: "Nope" } }
    assert_response :not_found
  end

  test "a writer records mock poll responses and sees who is likely to win" do
    own = ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Meera Patil", is_own_politician: true) }
    opponent = ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Ravi Kale") }
    sign_in @alice
    get ground_reports_village_path(@village)
    assert_select "button", text: "Record response"

    assert_difference -> { GroundReports::MockPollResponse.unscoped.count }, 2 do
      post ground_reports_village_mock_poll_responses_path(@village), params: { mock_poll_response: {
        politician_id: own.id, respondent_name: "Asha", respondent_mobile: "9876543210",
        preference_basis: "individual", vote_choice: "yes", note: "Knows the candidate", organization_id: 0
      } }
      post ground_reports_village_mock_poll_responses_path(@village), params: { mock_poll_response: {
        politician_id: opponent.id, respondent_name: "Ramesh", preference_basis: "party", vote_choice: "no"
      } }
    end
    saved = GroundReports::MockPollResponse.unscoped.order(:id).last(2)
    assert_equal [ @org ], saved.map(&:organization).uniq
    assert_equal [ @alice ], saved.map(&:created_by).uniq
    assert_equal true, saved.find { |row| row.respondent_name == "Asha" }.vote_intent

    get ground_reports_village_path(@village)
    assert_match "Likely to win: Meera Patil", @response.body
    assert_select "tr[data-politician='#{own.id}'] td[data-count=yes]", text: "1"
    assert_select "tr[data-politician='#{opponent.id}'] td[data-count=no]", text: "1"
    assert_match "Knows the candidate", @response.body

    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org Poll", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      politician = Politician.create!(name: "Other Candidate")
      GroundReports::MockPollResponse.create!(
        village: @village, politician: politician, created_by: @alice,
        respondent_name: "Secret Voter", preference_basis: :party, vote_choice: "yes"
      )
    end
    get ground_reports_village_path(@village)
    assert_no_match(/Secret Voter/, @response.body)

    post ground_reports_village_mock_poll_responses_path(@outside), params: { mock_poll_response: {
      politician_id: own.id, respondent_name: "Nope", preference_basis: "individual", vote_choice: "yes"
    } }
    assert_response :not_found
  end

  test "a read-only user sees the mock poll and cannot record a response" do
    ActsAsTenant.with_tenant(@org) do
      politician = Politician.create!(name: "Meera Patil", is_own_politician: true)
      GroundReports::MockPollResponse.create!(
        village: @village, politician: politician, created_by: @alice,
        respondent_name: "Asha", preference_basis: :individual, vote_choice: "yes"
      )
    end
    reader = User.create!(organization: @org, role: @read, name: "Kiran", email: "gr-poll-read@example.com", password: "password123")
    sign_in reader
    get ground_reports_village_path(@village)
    assert_match "Likely to win: Meera Patil", @response.body
    assert_select "button", text: "Record response", count: 0

    post ground_reports_village_mock_poll_responses_path(@village), params: { mock_poll_response: {
      respondent_name: "Nope", preference_basis: "party", vote_choice: "no"
    } }
    assert_response :not_found
  end

  test "the sidebar shows Ground Reports only with module access" do
    sign_in @alice
    get root_path
    assert_select "a[href=?]", ground_reports_villages_path, text: "Ground Reports"

    outsider = User.create!(organization: @org, role: @none, name: "Out", email: "gr-nav@example.com", password: "password123")
    sign_in outsider
    get root_path
    assert_select "a[href=?]", ground_reports_villages_path, count: 0
  end
end
