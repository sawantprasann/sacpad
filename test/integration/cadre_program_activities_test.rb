require "test_helper"

# Story 2.1 — base capture: rendered form scope, write-gated create, subtree list, activity log.
class CadreProgramActivitiesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    @other = ActsAsTenant.without_tenant { Organization.create!(name: "Org B") }

    @write = Role.create!(name: "Field Cadre", slug: "field-cadre")
    @write.role_permissions.create!(module_name: "cadre_program", access_level: "write")
    @read = Role.create!(name: "Cadre Viewer", slug: "cadre-viewer")
    @read.role_permissions.create!(module_name: "cadre_program", access_level: "read")

    @root  = User.create!(organization: @org, role: @write, name: "Root",  email: "cadre-root@example.com",  password: "password123")
    @alice = User.create!(organization: @org, role: @write, name: "Alice", email: "cadre-alice@example.com", password: "password123", parent: @root)
    @bob   = User.create!(organization: @org, role: @write, name: "Bob",   email: "cadre-bob@example.com",   password: "password123", parent: @root)
    @reader = User.create!(organization: @org, role: @read, name: "Nisha", email: "cadre-nisha@example.com", password: "password123", parent: @root)
  end

  def make_activity(owner:, category: :program_by_party, notes: "Warm reaction", org: @org)
    ActsAsTenant.with_tenant(org) do
      attrs = { owner: owner, category: category, impact_notes: notes }
      case category.to_s
      when "program_by_party", "personal_program"
        attrs[:program_attributes] = { program_name: "Booth meeting" }
      when "leadership_meets"
        attrs[:leadership_meet_attributes] = { whom_to_meet: "Sarpanch" }
      when "party_programs_hosted"
        attrs[:party_program_hosted_attributes] = { program_name: "Andolan" }
      when "personal_activities"
        attrs[:personal_activity_attributes] = { activity_name: "Village visit" }
      when "one_to_one"
        attrs[:one_to_one_attributes] = { karyakarta_name_text: "Sita" }
      end
      CadreProgram::CadreActivity.create!(attrs)
    end
  end

  test "the new form posts cadre_activity and labels Media Value" do
    sign_in @alice
    get new_cadre_program_activity_path
    assert_response :success
    assert_select "select[name=?]", "cadre_activity[category]"
    assert_select "textarea[name=?]", "cadre_activity[impact_notes]"
    assert_select "input[type=file][name=?]", "cadre_activity[photos][]"
    assert_match "Media Value", @response.body
    assert_select "select.min-h-11"
    assert_select "button[type=submit].cursor-pointer", text: "Create activity"
  end

  test "a write user logs an activity with a photo; owner and org come from the session" do
    sign_in @alice
    photo = fixture_file_upload("photo.png", "image/png")
    assert_difference -> { CadreProgram::CadreActivity.unscoped.count }, 1 do
      assert_difference -> { ActivityLog.where(action: "cadre_activity.created").count }, 1 do
        post cadre_program_activities_path, params: { cadre_activity: {
          category: "program_by_party", impact_notes: "Likely to move votes", photos: [ photo ],
          program_attributes: { program_name: "Booth meeting" }
        } }
      end
    end
    activity = CadreProgram::CadreActivity.unscoped.order(:id).last
    assert_redirected_to cadre_program_activity_path(activity)
    assert_equal @alice, activity.owner
    assert_equal @org, activity.organization
    assert activity.program_by_party?
    assert activity.photos.attached?
    log = ActivityLog.order(:id).last
    assert_equal @alice, log.actor
    assert_equal "CadreProgram::CadreActivity", log.record_type
    assert_equal activity.id, log.record_id
    assert_equal @org.id, log.organization_id
  end

  test "organization_id in params is ignored" do
    sign_in @alice
    post cadre_program_activities_path, params: { cadre_activity: {
      category: "one_to_one", impact_notes: "Met in the lane", organization_id: @other.id,
      one_to_one_attributes: { karyakarta_name_text: "Sita" }
    } }
    activity = CadreProgram::CadreActivity.unscoped.order(:id).last
    assert_equal @org, activity.organization
  end

  test "a missing category does not save" do
    sign_in @alice
    assert_no_difference -> { CadreProgram::CadreActivity.unscoped.count } do
      post cadre_program_activities_path, params: { cadre_activity: { impact_notes: "No category" } }
    end
    assert_response :unprocessable_entity
  end

  test "a read-only user can open an in-subtree activity and cannot create" do
    mine = make_activity(owner: @reader, notes: "Reader note")
    sign_in @reader
    get cadre_program_activities_path
    assert_response :success
    assert_match "Reader note", @response.body
    get cadre_program_activity_path(mine)
    assert_response :success
    assert_match "Media Value", @response.body
    post cadre_program_activities_path, params: { cadre_activity: { category: "one_to_one" } }
    assert_response :not_found
  end

  test "the list hides a peer and a discarded row; a peer show is 404" do
    make_activity(owner: @alice, notes: "Alice rally")
    peer = make_activity(owner: @bob, notes: "Bob rally")
    discarded = make_activity(owner: @alice, notes: "Alice archived")
    ActsAsTenant.with_tenant(@org) { discarded.discard }

    sign_in @alice
    get cadre_program_activities_path
    assert_response :success
    assert_match "Alice rally", @response.body
    assert_no_match(/Bob rally/, @response.body)
    assert_no_match(/Alice archived/, @response.body)

    get cadre_program_activity_path(peer)
    assert_response :not_found
  end

  test "category filter narrows the list" do
    make_activity(owner: @alice, category: :leadership_meets, notes: "Met the sarpanch")
    make_activity(owner: @alice, category: :one_to_one, notes: "Lane meeting")
    sign_in @alice
    get cadre_program_activities_path(category: "leadership_meets")
    assert_match "Met the sarpanch", @response.body
    assert_no_match(/Lane meeting/, @response.body)
  end

  test "the form renders every detail shape under cadre_activity params" do
    User.create!(organization: @other, role: @write, name: "Outsider", email: "cadre-form-outsider@example.com", password: "password123")
    sign_in @alice
    get new_cadre_program_activity_path
    assert_response :success
    assert_select "input[name=?]", "cadre_activity[program_attributes][program_name]"
    assert_select "input[name=?]", "cadre_activity[leadership_meet_attributes][whom_to_meet]"
    assert_select "input[name=?]", "cadre_activity[party_program_hosted_attributes][program_name]"
    assert_select "input[name=?]", "cadre_activity[personal_activity_attributes][activity_name]"
    assert_select "input[name=?]", "cadre_activity[one_to_one_attributes][karyakarta_name_text]"
    assert_select "select[name=?]", "cadre_activity[one_to_one_attributes][karyakarta_user_id]"
    assert_match ">Alice<", @response.body
    assert_no_match(/Outsider/, @response.body)
  end

  test "a leadership activity stores only the leadership detail and shows it" do
    sign_in @alice
    post cadre_program_activities_path, params: { cadre_activity: {
      category: "leadership_meets", impact_notes: "Useful meeting",
      leadership_meet_attributes: { whom_to_meet: "MLA", point_of_discussion: "The road" },
      program_attributes: { program_name: "Should not stick" }
    } }
    activity = CadreProgram::CadreActivity.unscoped.order(:id).last
    assert_redirected_to cadre_program_activity_path(activity)
    ActsAsTenant.with_tenant(@org) do
      assert_equal "MLA", activity.leadership_meet.whom_to_meet
      assert_nil activity.program
    end
    follow_redirect!
    assert_match "Whom to meet", @response.body
    assert_match "MLA", @response.body
    assert_match "Useful meeting", @response.body
    assert_select "nav[aria-label=Breadcrumb] a", text: "Cadre Program"
    assert_select "nav[aria-label=Breadcrumb] a", text: "Leadership Meets"
    assert_select "nav[aria-label=Breadcrumb] [aria-current=page]", text: "MLA"
  end

  test "one to one rejects a karyakarta from another organization" do
    outsider = User.create!(organization: @other, role: @write, name: "Outsider", email: "cadre-outsider@example.com", password: "password123")
    sign_in @alice
    assert_no_difference -> { CadreProgram::CadreActivity.unscoped.count } do
      post cadre_program_activities_path, params: { cadre_activity: {
        category: "one_to_one",
        one_to_one_attributes: { karyakarta_user_id: outsider.id }
      } }
    end
    assert_response :unprocessable_entity
  end

  test "personal program uses the shared program detail" do
    sign_in @alice
    post cadre_program_activities_path, params: { cadre_activity: {
      category: "personal_program",
      program_attributes: { program_name: "Evening round", location: "Wadi" }
    } }
    activity = CadreProgram::CadreActivity.unscoped.order(:id).last
    assert_redirected_to cadre_program_activity_path(activity)
    ActsAsTenant.with_tenant(@org) do
      assert_instance_of CadreProgram::CadreActivityProgram, activity.program
      assert_equal "Wadi", activity.program.location
    end
  end
end
