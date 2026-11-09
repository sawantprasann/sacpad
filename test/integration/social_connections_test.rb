require "test_helper"

class SocialConnectionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Social Org #{SecureRandom.hex(4)}") }
    ActsAsTenant.with_tenant(@org) do
      @admin = user_with_role("org_admin")
      @manager = user_with_role("manager")
      @writer = user_with_access("write")
      @reader = user_with_access("read")
    end
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new(
      provider: "facebook",
      uid: "fb-user-1",
      credentials: { token: "short-user-token" }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:facebook] = nil
  end

  test "an org admin sees the network section" do
    sign_in @admin
    get social_connections_path
    assert_response :success
    assert_match I18n.t("social.title"), response.body
    assert_match I18n.t("social.coming_next"), response.body
  end

  test "a manager sees the page table and cannot connect or disconnect" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", username: "youth", url: "https://facebook.com/youth", access_token: "page-secret-token", status: :active)
    end
    sign_in @manager
    get social_connections_path
    assert_response :success
    assert_match "Youth Page", response.body
    assert_select "a[href=?]", new_social_connection_path
    assert_no_match I18n.t("social.coming_next"), response.body
    assert_no_match I18n.t("social.connect_facebook"), response.body
    get new_social_connection_path
    assert_response :success
    assert_select "[data-controller=media-preview]"
    assert_select "input[type=file][name=?][accept=?]", "bulk_post[media][]", "image/*,video/*"
    assert_match I18n.t("social.composer_media_add"), response.body
    assert_match I18n.t("social.composer_media_remove"), response.body
    get social_connection_path(page)
    assert_response :success
    assert_match "https://facebook.com/youth", response.body
    assert_no_match "page-secret-token", response.body
    assert_no_match I18n.t("social.disconnect"), response.body
    delete social_connection_path(page)
    assert_response :not_found
  end

  test "a page shows its posts and their metrics" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "page-secret-token", status: :active)
      post = SocialMedia::BulkPost.create!(owner: @admin, body: "Booth meeting tonight")
      target = post.targets.create!(social_page: page, status: :published, published_at: Time.current)
      target.post_metrics.create!(likes_count: 1284, comments_count: 17, shares_count: 9, views_count: 40, fetched_at: Time.current)
      page.metric_snapshots.create!(captured_on: Date.current, followers_count: 5400, posts_count: 12, views_count: 800, organic_reach: 300, paid_reach: 50)
    end
    sign_in @manager
    get social_connection_path(page)
    assert_response :success
    assert_match "Booth meeting tonight", response.body
    assert_select "[data-total=followers]", text: "5,400"
    assert_select "[data-total=reach]", text: "350"
    assert_select "[data-total=likes]", count: 0
    assert_select "[data-metric=likes]", text: "1,284"
    assert_select "[data-metric=comments]", text: "17"
    assert_no_match "page-secret-token", response.body
  end

  test "opening a connected page pulls its facebook posts and counts" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "GV Creations", access_token: "page-secret-token", status: :active)
    end
    body = {
      "summary" => { "total_count" => 8 },
      "data" => [ {
        "id" => "111_999",
        "message" => "Booth work today",
        "created_time" => "2026-11-01T10:00:00+0000",
        "permalink_url" => "https://www.facebook.com/111/posts/999",
        "full_picture" => "https://example.com/photo.jpg",
        "shares" => { "count" => 4 },
        "comments" => { "summary" => { "total_count" => 3 } },
        "reactions" => { "summary" => { "total_count" => 12 } }
      } ]
    }
    api = MetaApi.singleton_class
    graph = MetaApi::Graph.singleton_class
    api.alias_method(:__orig_configured?, :configured?)
    graph.alias_method(:__orig_get, :get)
    MetaApi.define_singleton_method(:configured?) { true }
    MetaApi::Graph.define_singleton_method(:get) { |*, **| body }

    sign_in @admin
    get social_connection_path(page)
    assert_response :success
    assert_match "Booth work today", response.body
    assert_select "[data-metric=likes]", text: "12"
    assert_select "[data-metric=comments]", text: "3"
    assert_select "[data-metric=shares]", text: "4"
    assert_select "[data-total=posts]", text: "8"
    assert_match "https://example.com/photo.jpg", response.body
    assert_no_match "page-secret-token", response.body

    get social_connection_path(page)
    ActsAsTenant.with_tenant(@org) do
      assert_equal 1, SocialMedia::BulkPost.count
      assert_equal 1, page.bulk_post_targets.count
      assert_equal 1, SocialMedia::PostMetric.count
    end
  ensure
    api&.alias_method(:configured?, :__orig_configured?)
    graph&.alias_method(:get, :__orig_get)
  end

  test "a manager publishes a text post to the selected facebook page" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "page-secret-token", status: :active)
    end
    graph = MetaApi::Graph.singleton_class
    graph.alias_method(:__orig_post, :post)
    MetaApi::Graph.define_singleton_method(:post) { |*, **| { "id" => "111_555" } }

    sign_in @manager
    post publish_social_connections_path, params: { bulk_post: { body: "Booth meeting tonight" }, page_ids: [ page.id ] }
    assert_redirected_to social_connections_path
    follow_redirect!
    assert_match I18n.t("social.publish_sent"), response.body

    ActsAsTenant.with_tenant(@org) do
      target = page.bulk_post_targets.find_by!(external_post_id: "111_555")
      assert target.status_published?
      assert_equal "Booth meeting tonight", target.bulk_post.body
      assert_equal "https://www.facebook.com/111/posts/555", target.permalink
    end
    assert_no_match "page-secret-token", response.body
  ensure
    graph&.alias_method(:post, :__orig_post)
  end

  test "a photo post is uploaded to the selected facebook page" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "page-secret-token", status: :active)
    end
    graph = MetaApi::Graph.singleton_class
    graph.alias_method(:__orig_upload, :upload)
    MetaApi::Graph.define_singleton_method(:upload) { |*, **| { "id" => "900", "post_id" => "111_777" } }
    image = fixture_file_upload("photo.png", "image/png")

    sign_in @manager
    post publish_social_connections_path, params: { bulk_post: { body: "Poster", media: [ image ] }, page_ids: [ page.id ] }
    assert_redirected_to social_connections_path

    ActsAsTenant.with_tenant(@org) do
      target = page.bulk_post_targets.find_by!(external_post_id: "111_777")
      assert target.status_published?
      assert target.bulk_post.images.attached?
    end
  ensure
    graph&.alias_method(:upload, :__orig_upload)
  end

  test "a reader cannot publish a facebook post" do
    sign_in @reader
    post publish_social_connections_path, params: { bulk_post: { body: "Nope" }, page_ids: [ "1" ] }
    assert_response :not_found
  end

  test "a user without social access is denied" do
    outsider = nil
    ActsAsTenant.with_tenant(@org) do
      role = Role.create!(name: "No Social", slug: "no-social-#{SecureRandom.hex(4)}")
      outsider = User.create!(organization: @org, role: role, name: "Outsider", email: "out-#{SecureRandom.hex(4)}@example.com", password: "password")
    end
    sign_in outsider
    get social_connections_path
    assert_response :not_found
  end

  test "callback keeps the page token out of the html and the database column" do
    sign_in @admin
    pages = [ {
      "id" => "111",
      "name" => "Youth Page",
      "category" => "Politician",
      "username" => "youth",
      "access_token" => "page-secret-token",
      "instagram_business_account" => { "id" => "ig-9", "username" => "youth.ig" }
    } ]
    with_facebook_pages(pages) do
      post "/auth/facebook"
      follow_redirect!
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match "Youth Page", response.body
    assert_match "youth.ig", response.body
    assert_no_match "page-secret-token", response.body
    assert_no_match "long-lived-secret", response.body
    assert_no_match "short-user-token", response.body

    pending = ActsAsTenant.with_tenant(@org) { SocialMedia::PendingConnection.order(:id).last }
    raw = SocialMedia::PendingConnection.connection.select_value(
      SocialMedia::PendingConnection.sanitize_sql_array([ "SELECT payload FROM social_pending_connections WHERE id = ?", pending.id ])
    )
    assert_not_includes raw, "page-secret-token"
  end

  test "callback lists a page that was granted for the current selection only" do
    sign_in @admin
    graph = MetaApi::Graph.singleton_class
    graph.send(:alias_method, :__orig_long_lived_user_token, :long_lived_user_token)
    graph.send(:alias_method, :__orig_get_all, :get_all)
    graph.send(:alias_method, :__orig_get, :get)
    MetaApi::Graph.define_singleton_method(:long_lived_user_token) { |_| "long-lived-secret" }
    MetaApi::Graph.define_singleton_method(:get_all) { |*, **| [] }
    MetaApi::Graph.define_singleton_method(:get) do |path, _params = {}|
      if path == "/debug_token"
        { "data" => { "granular_scopes" => [ { "scope" => "pages_show_list", "target_ids" => [ "222" ] } ] } }
      else
        { "id" => "222", "name" => "GV Creations", "access_token" => "page-secret-token" }
      end
    end

    post "/auth/facebook"
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match "GV Creations", response.body
    assert_no_match "page-secret-token", response.body
  ensure
    graph&.send(:alias_method, :long_lived_user_token, :__orig_long_lived_user_token)
    graph&.send(:alias_method, :get_all, :__orig_get_all)
    graph&.send(:alias_method, :get, :__orig_get)
  end

  test "save stores only the ticked facebook page and encrypts the token" do
    sign_in @admin
    pending = checklist
    post save_social_connections_path, params: { pending_id: pending.id, page_ids: [ "111" ], instagram_ids: [ "ig-9", "ig-evil" ] }
    assert_redirected_to social_connections_path

    ActsAsTenant.with_tenant(@org) do
      assert_equal 2, SocialMedia::SocialPage.count
      page = SocialMedia::SocialPage.find_by!(external_id: "111")
      assert page.facebook?
      assert_equal "page-secret-token", page.access_token
      assert_equal @org.id, page.organization_id
      instagram = SocialMedia::SocialPage.find_by!(provider: :instagram, external_id: "ig-9")
      assert_equal "youth.ig", instagram.username
      assert_equal "https://www.instagram.com/youth.ig/", instagram.url
      assert_equal "111", instagram.parent_external_id
      assert_equal "page-secret-token", instagram.access_token
      assert_nil SocialMedia::SocialPage.find_by(external_id: "ig-evil")
      [ page, instagram ].each do |saved|
        raw = SocialMedia::SocialPage.connection.select_value(
          SocialMedia::SocialPage.sanitize_sql_array([ "SELECT access_token FROM social_pages WHERE id = ?", saved.id ])
        )
        assert_not_includes raw, "page-secret-token"
      end
    end
  end

  test "saving again updates the same page" do
    sign_in @admin
    pending = checklist
    post save_social_connections_path, params: { pending_id: pending.id, page_ids: [ "111" ] }
    again = checklist("page-secret-token-2", "Youth Page renamed")
    post save_social_connections_path, params: { pending_id: again.id, page_ids: [ "111" ] }

    ActsAsTenant.with_tenant(@org) do
      assert_equal 1, SocialMedia::SocialPage.count
      assert_equal "Youth Page renamed", SocialMedia::SocialPage.find_by!(external_id: "111").name
    end
  end

  test "a different writer cannot open someone else's checklist" do
    pending = nil
    other = nil
    ActsAsTenant.with_tenant(@org) do
      pending = checklist_for(@admin)
      other = user_with_role("org_admin")
    end
    sign_in other
    get choose_social_connections_path(pending_id: pending.id)
    assert_response :not_found
  end

  test "another user cannot open the checklist" do
    pending = nil
    ActsAsTenant.with_tenant(@org) { pending = checklist_for(@admin) }
    sign_in @reader
    get choose_social_connections_path(pending_id: pending.id)
    assert_response :not_found
  end

  test "a reader cannot disconnect a page" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "page-secret-token", status: :active)
    end
    sign_in @reader
    delete social_connection_path(page)
    assert_response :not_found
  end

  test "disconnect clears the token and keeps the page name" do
    page = nil
    instagram = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "page-secret-token", status: :active)
      instagram = SocialMedia::SocialPage.create!(owner: @admin, provider: :instagram, external_id: "ig-9", name: "youth.ig", parent_external_id: "111", access_token: "page-secret-token", status: :active)
    end
    sign_in @admin
    delete social_connection_path(page)
    assert_redirected_to social_connections_path
    ActsAsTenant.with_tenant(@org) do
      page.reload
      instagram.reload
      assert page.connection_disconnected?
      assert instagram.connection_disconnected?
      assert_nil page.access_token
      assert_nil instagram.access_token
      assert_equal "Youth Page", page.name
    end
  end

  test "another organization cannot see the page" do
    page = nil
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", name: "Youth Page", access_token: "secret", status: :active)
    end
    other = ActsAsTenant.without_tenant { Organization.create!(name: "Other #{SecureRandom.hex(4)}") }
    stranger = nil
    ActsAsTenant.with_tenant(other) { stranger = user_with_access("write", other) }
    sign_in stranger
    get social_connections_path
    assert_response :success
    assert_no_match "Youth Page", response.body
    delete social_connection_path(page)
    assert_response :not_found
  end

  test "sample preview is not available outside development" do
    sign_in @writer
    post preview_social_connections_path
    assert_response :not_found
  end

  test "deauthorize with a bad signature is rejected" do
    post "/meta/deauthorize", params: { signed_request: "abc.def" }
    assert_response :bad_request
  end

  test "deauthorize disconnects the pages granted by that facebook user" do
    ActsAsTenant.with_tenant(@org) do
      SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", provider_uid: "fb-user-1", name: "Youth Page", access_token: "page-secret-token", status: :active)
    end
    post "/meta/deauthorize", params: { signed_request: signed("user_id" => "fb-user-1") }
    assert_response :success
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.find_by!(external_id: "111")
      assert page.connection_disconnected?
      assert_nil page.access_token
      assert_equal "Youth Page", page.name
    end
  end

  test "data deletion removes the token and the status page is public" do
    ActsAsTenant.with_tenant(@org) do
      SocialMedia::SocialPage.create!(owner: @admin, provider: :facebook, external_id: "111", provider_uid: "fb-user-1", name: "Youth Page", access_token: "page-secret-token", status: :active)
    end
    post "/meta/data_deletion", params: { signed_request: signed("user_id" => "fb-user-1") }
    assert_response :success
    body = JSON.parse(response.body)
    perform_enqueued_jobs
    ActsAsTenant.with_tenant(@org) do
      page = SocialMedia::SocialPage.find_by!(external_id: "111")
      assert_nil page.access_token
      assert_nil page.name
    end
    get body["url"]
    assert_response :success
    assert_match I18n.t("social.deletion_completed"), response.body
  end

  private

  def user_with_role(slug, org = @org)
    role = Role.find_or_create_by!(slug: slug) { |record| record.name = slug.titleize }
    role.role_permissions.find_or_create_by!(module_name: "social_media") { |permission| permission.access_level = "write" }
    User.create!(organization: org, role: role, name: slug.titleize, email: "#{slug}-#{SecureRandom.hex(4)}@example.com", password: "password")
  end

  def user_with_access(level, org = @org)
    role = Role.create!(name: "Social #{level}", slug: "social-#{level}-#{SecureRandom.hex(4)}")
    role.role_permissions.create!(module_name: "social_media", access_level: level)
    User.create!(organization: org, role: role, name: "Social #{level}", email: "social-#{SecureRandom.hex(4)}@example.com", password: "password")
  end

  def checklist(token = "page-secret-token", name = "Youth Page")
    ActsAsTenant.with_tenant(@org) { checklist_for(@admin, token, name) }
  end

  def checklist_for(user, token = "page-secret-token", name = "Youth Page")
    user.pending_connections.create!(
      provider: :facebook,
      provider_uid: "fb-user-1",
      items: [ {
        "id" => "111",
        "name" => name,
        "access_token" => token,
        "instagram_business_account" => { "id" => "ig-9", "username" => "youth.ig" }
      } ]
    )
  end

  def with_facebook_pages(pages)
    graph = MetaApi::Graph.singleton_class
    graph.send(:alias_method, :__orig_long_lived_user_token, :long_lived_user_token)
    graph.send(:alias_method, :__orig_get_all, :get_all)
    MetaApi::Graph.define_singleton_method(:long_lived_user_token) { |_| "long-lived-secret" }
    MetaApi::Graph.define_singleton_method(:get_all) { |*, **| pages }
    yield
  ensure
    graph.send(:alias_method, :long_lived_user_token, :__orig_long_lived_user_token)
    graph.send(:alias_method, :get_all, :__orig_get_all)
  end

  def signed(payload)
    encoded = Base64.urlsafe_encode64(payload.to_json).delete("=")
    sig = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", MetaCredentials.app_secret, encoded)).delete("=")
    "#{sig}.#{encoded}"
  end
end
