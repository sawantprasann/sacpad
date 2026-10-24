require "test_helper"
require "roo"

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
        issue_text: "Water shortage", resolution_text: "Tanker arranged",
        estimated_cost: "1500.5", reported_at: Date.current,
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
    assert_equal BigDecimal("1500.5"), report.estimated_cost
    ActsAsTenant.with_tenant(@org) do
      assert_equal "The well is dry", report.testimonials.first.text_content
    end

    get ground_reports_village_report_path(@village, report)
    assert_response :success
    assert_match "Asha", @response.body
    assert_match "1,500.5", @response.body
    assert_select "nav[aria-label=Breadcrumb] a", text: "Ground Reports"

    get ground_reports_village_path(@village)
    assert_select "h2", text: "Issues"
    assert_select "th", text: "Estimated cost"
    assert_match "1,500.5", @response.body
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

  test "a writer maintains worship places, including a yatra, work inline, and political history" do
    party = Party.create!(name: "Sample Party")
    sign_in @alice
    get ground_reports_village_path(@village)
    assert_response :success
    assert_match "Worship places", @response.body
    assert_match "Work inline", @response.body
    assert_match "Total nidhi", @response.body
    assert_no_match(/Current post/, @response.body)
    assert_no_match(/Save yatra/, @response.body)
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

    post ground_reports_village_worship_places_path(@village), params: { worship_place: {
      name: "Pandharpur yatra", place_type: "Yatra"
    } }
    assert_difference -> { GroundReports::VillageWork.unscoped.count }, 1 do
      post ground_reports_village_village_works_path(@village), params: { village_work: {
        title: "Road from Nimgaon to the highway", concern_person: "Gram Sevak", nidhi_asked: "250000",
        nidhi_category: "mla_fund", status: "not_started", organization_id: 0
      } }
    end
    work = GroundReports::VillageWork.unscoped.order(:id).last
    assert_equal @org, work.organization
    assert_equal "mla_fund", work.nidhi_category

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
    assert_match "Pandharpur yatra", @response.body
    assert_match "Road from Nimgaon to the highway", @response.body
    assert_match "Total nidhi", @response.body
    assert_match "250,000", @response.body
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
    assert_select "a[href=?]", new_ground_reports_import_path(kind: "mock_poll", village_id: @village.id), text: "Upload"

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
    assert_select "a", text: "Upload", count: 0

    post ground_reports_village_mock_poll_responses_path(@village), params: { mock_poll_response: {
      respondent_name: "Nope", preference_basis: "party", vote_choice: "no"
    } }
    assert_response :not_found
  end

  test "the village list filters by taluka and shows each village's total nidhi" do
    district = District.create!(state: @village.assembly.loksabha.state, name: "Pune")
    indapur = district.talukas.create!(name: "Indapur")
    baramati = district.talukas.create!(name: "Baramati")
    @village.update!(taluka: indapur)
    kalas = @village.assembly.villages.create!(name: "Kalas", taluka: baramati)
    akluj = @village.assembly.villages.create!(name: "Akluj", taluka: indapur)
    ActsAsTenant.with_tenant(@org) do
      GroundReports::VillageWork.create!(
        village: @village, title: "Road", concern_person: "Gram Sevak",
        nidhi_asked: 150000, nidhi_category: :mla_fund, status: :not_started
      )
      GroundReports::VillageWork.create!(
        village: @village, title: "Well", concern_person: "Sarpanch",
        nidhi_asked: 100000.5, nidhi_category: :dpdc, status: :in_progress
      )
    end
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org Nidhi", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::VillageWork.create!(
        village: @village, title: "Hidden road", concern_person: "Other",
        nidhi_asked: 999999, nidhi_category: :other, nidhi_category_name: "Special", status: :not_started
      )
    end

    sign_in @alice
    get ground_reports_villages_path
    assert_response :success
    assert_select "select[name=taluka_id] option", text: "Indapur"
    assert_equal [ "All villages", "Akluj", "Kalas", "Nimgaon" ],
      css_select("select[name=village_id] option").map { |option| option.text.strip }
    assert_equal [ "Akluj", "Kalas", "Nimgaon" ],
      css_select("table tbody tr td:first-child").map { |cell| cell.text.strip }
    assert_select "th", text: "Taluka"
    assert_select "th", text: "Assembly", count: 0
    assert_select "th", text: "Total nidhi"
    assert_select "a[href=?][aria-label=View]", ground_reports_village_path(@village)
    assert_select "a[href=?]", ground_reports_village_path(@village), text: "Nimgaon"
    assert_match "Nimgaon", @response.body
    assert_match "Kalas", @response.body
    assert_match "250,000.5", @response.body
    assert_no_match(/999,999/, @response.body)

    get ground_reports_villages_path(taluka_id: baramati.id)
    assert_match "Kalas", @response.body
    assert_no_match(/Nimgaon/, @response.body)
    assert_equal [ "All villages", "Kalas" ],
      css_select("select[name=village_id] option").map { |option| option.text.strip }

    get ground_reports_villages_path(village_id: akluj.id)
    assert_equal [ "Akluj" ], css_select("table tbody tr td:first-child").map { |cell| cell.text.strip }

    get ground_reports_villages_path(taluka_id: 0)
    assert_match "No villages match this taluka.", @response.body
    assert_no_match(/Kalas/, @response.body)

    get ground_reports_villages_path(village_id: 0)
    assert_match "No villages match this filter.", @response.body

    get ground_reports_village_path(@village)
    assert_match "250,000.5", @response.body
    assert_no_match(/Current post/, @response.body)
    assert_no_match(/999,999/, @response.body)

    get ground_reports_village_path(kalas)
    assert_match "Total nidhi", @response.body
  end

  test "the village workbook has one sheet per section and stays in scope" do
    party = Party.create!(name: "Sample Party")
    ActsAsTenant.with_tenant(@org) do
      report = GroundReports::GroundReport.create!(
        owner: @alice, village: @village, issue_text: "Water shortage",
        resolution_text: "Tanker arranged", estimated_cost: 1500.5, reported_at: Date.new(2026, 1, 2)
      )
      report.testimonials.create!(person_name: "Asha", content_type: "text", text_content: "The well is dry")
      20.times do |n|
        GroundReports::GroundReport.create!(
          owner: @alice, village: @village, issue_text: "Extra issue #{n}", reported_at: Date.current
        )
      end
      GroundReports::GroundReport.create!(
        owner: @bob, village: @village, issue_text: "Peer issue", reported_at: Date.current
      )
      GroundReports::WorshipPlace.create!(village: @village, name: "Jama Masjid", place_type: "Mosque", notes: "Friday prayers")
      GroundReports::VillagePoliticalPosition.create!(
        village: @village, party: party, representative_name: "New Sarpanch",
        position_title: "Sarpanch", started_at: Date.new(2024, 6, 1)
      )
      GroundReports::VillageWork.create!(
        village: @village, title: "Road from Nimgaon", concern_person: "Gram Sevak",
        nidhi_asked: 250_000, nidhi_category: :mla_fund, status: :not_started
      )
      GroundReports::VillageLocalKaryakarta.create!(
        village: @village, name: "Asha Worker", phone: "9876543210", address: "Lane 2", notes: "Booth 3"
      )
      GroundReports::VillageLocalAdminContact.create!(
        village: @village, name: "Ramesh", role_title: "Gram Sevak", phone: "9123456780"
      )
      politician = Politician.create!(name: "Meera Patil", is_own_politician: true)
      GroundReports::MockPollResponse.create!(
        village: @village, politician: politician, created_by: @alice,
        respondent_name: "Survey Asha", respondent_mobile: "9876543210",
        preference_basis: :individual, vote_choice: "yes", note: "Knows the candidate"
      )
    end
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Org Export", constituency: @org.constituency) }
    ActsAsTenant.with_tenant(other) do
      GroundReports::WorshipPlace.create!(village: @village, name: "Secret Shrine", place_type: "Temple")
    end

    sign_in @alice
    get ground_reports_village_path(@village)
    assert_response :success
    assert_select "a", text: "Export Excel"
    assert_select "a[href=?]", ground_reports_village_path(@village, format: :xlsx)
    assert_select "a[aria-label='Create issue']"
    assert_no_match(/Water shortage/, @response.body)

    get ground_reports_village_path(@village, format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
    assert_match(/ground-report-nimgaon\.xlsx/, @response.headers["Content-Disposition"])

    sheets = workbook_sheets
    assert_equal [ "Issues", "Worship places", "Political position", "Work inline", "People", "Mock poll" ], sheets.keys
    assert_includes sheets["Issues"].flatten.map(&:to_s), "Water shortage"
    assert_includes sheets["Issues"].flatten.map(&:to_s), "Tanker arranged"
    assert_includes sheets["Issues"].flatten.map(&:to_s), "1500.5"
    assert_includes sheets["Issues"].flatten.map(&:to_s), "02 Jan 2026"
    assert_not_includes sheets["Issues"].flatten.map(&:to_s), "Peer issue"
    assert_includes sheets["Worship places"].flatten.map(&:to_s), "Jama Masjid"
    assert_not_includes sheets["Worship places"].flatten.map(&:to_s), "Secret Shrine"
    assert_includes sheets["Political position"].flatten.map(&:to_s), "New Sarpanch"
    assert_includes sheets["Political position"].flatten.map(&:to_s), "Current"
    assert_includes sheets["Work inline"].flatten.map(&:to_s), "Road from Nimgaon"
    assert_includes sheets["Work inline"].flatten.map(&:to_s), "MLA fund"
    assert_includes sheets["People"].flatten.map(&:to_s), "Asha Worker"
    assert_includes sheets["People"].flatten.map(&:to_s), "Karyakarta"
    assert_includes sheets["People"].flatten.map(&:to_s), "Administrative contact"
    assert_includes sheets["People"].flatten.map(&:to_s), "Ramesh"
    assert_includes sheets["Mock poll"].flatten.map(&:to_s), "Meera Patil"
    assert_includes sheets["Mock poll"].flatten.map(&:to_s), "Likely"
    assert_includes sheets["Mock poll"].flatten.map(&:to_s), "Survey Asha"
    assert_includes sheets["Mock poll"].flatten.map(&:to_s), "Knows the candidate"

    reader = User.create!(organization: @org, role: @read, name: "Nisha", email: "gr-export-read@example.com", password: "password123")
    sign_in reader
    get ground_reports_village_path(@village)
    assert_select "a[href=?]", ground_reports_village_path(@village, format: :xlsx)
    assert_select "a[aria-label='Create issue']", count: 0
    get ground_reports_village_path(@village, format: :xlsx)
    assert_response :success

    outsider = User.create!(organization: @org, role: @none, name: "Out", email: "gr-export-out@example.com", password: "password123")
    sign_in outsider
    get ground_reports_village_path(@village, format: :xlsx)
    assert_redirected_to root_path
  end

  def workbook_sheets
    file = Tempfile.new([ "export", ".xlsx" ])
    file.binmode
    file.write(@response.body)
    file.rewind
    book = Roo::Excelx.new(file.path)
    book.sheets.index_with { |name| book.sheet(name).to_a }
  ensure
    file&.close
  end

  test "each section can be edited, and delete asks first then soft-deletes" do
    party = Party.create!(name: "Sample Party")
    role = AdminContactRole.create!(name: "Gram Sevak Edit", slug: "gram-sevak-edit")
    politician = ActsAsTenant.with_tenant(@org) { Politician.create!(name: "Meera Patil", is_own_politician: true) }
    records = ActsAsTenant.with_tenant(@org) do
      {
        report: GroundReports::GroundReport.create!(
          owner: @alice, village: @village, issue_text: "Water shortage", reported_at: Date.current
        ),
        place: GroundReports::WorshipPlace.create!(village: @village, name: "Jama Masjid", place_type: "Mosque"),
        position: GroundReports::VillagePoliticalPosition.create!(
          village: @village, party: party, representative_name: "New Sarpanch",
          position_title: "Sarpanch", started_at: Date.current
        ),
        work: GroundReports::VillageWork.create!(
          village: @village, title: "Road repair", concern_person: "Gram Sevak",
          nidhi_asked: 1000, nidhi_category: :mla_fund, status: :not_started
        ),
        karyakarta: GroundReports::VillageLocalKaryakarta.create!(village: @village, name: "Asha Worker"),
        contact: GroundReports::VillageLocalAdminContact.create!(
          village: @village, name: "Ramesh", admin_contact_role: role
        ),
        survey: GroundReports::MockPollResponse.create!(
          village: @village, politician: politician, created_by: @alice,
          respondent_name: "Survey Asha", preference_basis: :individual, vote_choice: "yes"
        )
      }
    end
    peer = ActsAsTenant.with_tenant(@org) do
      GroundReports::GroundReport.create!(owner: @bob, village: @village, issue_text: "Peer issue", reported_at: Date.current)
    end

    sign_in @alice
    get ground_reports_village_path(@village)
    assert_response :success
    {
      "issue" => edit_ground_reports_village_report_path(@village, records[:report]),
      "worship place" => edit_ground_reports_village_worship_place_path(@village, records[:place]),
      "political position" => edit_ground_reports_village_political_position_path(@village, records[:position]),
      "work inline" => edit_ground_reports_village_village_work_path(@village, records[:work]),
      "karyakarta" => edit_ground_reports_village_local_karyakarta_path(@village, records[:karyakarta]),
      "administrative contact" => edit_ground_reports_village_local_admin_contact_path(@village, records[:contact]),
      "survey response" => edit_ground_reports_village_mock_poll_response_path(@village, records[:survey])
    }.each do |label, edit_path|
      assert_select "a[href=?][aria-label=Edit]", edit_path
      assert_select "button[aria-label=Delete][data-turbo-confirm=?]", "Delete this #{label}?"
      get edit_path
      assert_response :success
      get ground_reports_village_path(@village)
    end

    patch ground_reports_village_report_path(@village, records[:report]), params: {
      ground_report: { issue_text: "Pipeline leak", reported_at: Date.current, estimated_cost: "2500" }
    }
    assert_redirected_to ground_reports_village_path(@village)
    assert_equal "Pipeline leak", records[:report].reload.issue_text
    assert_equal BigDecimal("2500"), records[:report].estimated_cost

    patch ground_reports_village_worship_place_path(@village, records[:place]), params: {
      worship_place: { name: "Old Masjid", place_type: "Mosque" }
    }
    assert_equal "Old Masjid", records[:place].reload.name

    assert_no_difference -> { GroundReports::WorshipPlace.unscoped.count } do
      delete ground_reports_village_worship_place_path(@village, records[:place])
    end
    assert_redirected_to ground_reports_village_path(@village)
    assert records[:place].reload.discarded?
    assert_equal @alice.id, records[:place].discarded_by_id

    delete ground_reports_village_report_path(@village, records[:report])
    assert records[:report].reload.discarded?
    assert_equal @alice.id, records[:report].discarded_by_id

    get ground_reports_village_path(@village)
    assert_no_match(/Old Masjid/, @response.body)
    assert_no_match(/Pipeline leak/, @response.body)
    assert_match "Road repair", @response.body

    delete ground_reports_village_report_path(@village, peer)
    assert_response :not_found
    assert_not peer.reload.discarded?

    reader = User.create!(organization: @org, role: @read, name: "Nisha", email: "gr-edit-read@example.com", password: "password123")
    sign_in reader
    get ground_reports_village_path(@village)
    assert_select "button[aria-label=Delete]", count: 0
    assert_select "a[aria-label=Edit]", count: 0
    delete ground_reports_village_village_work_path(@village, records[:work])
    assert_response :not_found
    assert_not records[:work].reload.discarded?
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
