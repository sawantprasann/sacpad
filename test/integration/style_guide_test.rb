require "test_helper"

# Story 0.1a — the component library renders on the style-guide sample page.
class StyleGuideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.create!(name: "Org Admin", slug: "org_admin")
    @user = User.create!(organization: org, role: role, name: "Meera",
                         email: "meera@example.com", password: "password123")
  end

  test "requires authentication" do
    get "/style_guide"
    assert_redirected_to new_user_session_path
  end

  test "renders the TailAdmin component library (pills, chips, badges, alerts)" do
    sign_in @user
    get "/style_guide"
    assert_response :success
    # Status pills (labelled, never color-alone) and RAG chips (reserved palette)
    assert_match "In progress", @response.body
    assert_match "Blocked", @response.body
    assert_match "Pleased", @response.body
    assert_match "Displeased", @response.body
    # Theme token utility is generated (brand scale from the Tailwind @theme layer)
    assert_match "Style guide", @response.body
  end
end
