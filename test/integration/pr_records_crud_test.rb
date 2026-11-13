require "test_helper"
require "roo"

# Integration tests for PR Records CRUD — comprehensive tests covering
# org-scoping, policy authorization, and cross-org isolation

class PrRecordsCrudTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @org = ActsAsTenant.without_tenant { Organization.create!(name: "Test Org") }
    ActsAsTenant.with_tenant(@org) do
      # Create roles with PR access
      @member_role = Role.create!(
        name: "Member",
        slug: "member-#{Time.current.to_i}"
      )
      @member_role.role_permissions.create!(
        module_name: "pr",
        access_level: "write"
      )

      @admin_role = Role.create!(
        name: "Org Admin",
        slug: "org_admin-#{Time.current.to_i}"
      )
      @admin_role.role_permissions.create!(
        module_name: "pr",
        access_level: "write"
      )

      @user = User.create!(
        organization: @org,
        email: "user@example.com",
        password: "password",
        name: "Test User",
        role: @member_role
      )

      @admin = User.create!(
        organization: @org,
        email: "admin@example.com",
        password: "password",
        name: "Admin User",
        role: @admin_role
      )

      @category = PrCategory.find_by(slug: "electronic") || PrCategory.create!(
        name: "Electronic",
        slug: "electronic",
        active: true,
        display_order: 1
      )

      @platform = MediaPlatform.create!(name: "TV News", slug: "tv-news", active: true)
    end

    sign_in @user
  end

  test "category and platform menus list the blank choice once" do
    get new_pr_record_path
    assert_response :success
    assert_operator response.body.index("Add category"), :<, response.body.index('data-pr-record-form-target="entryRows"')
    assert_select "select[name*='pr_category_id']" do |selects|
      selects.each do |select|
        blanks = select.css("option").select { |option| option.text == "Select a category..." }
        assert_equal 1, blanks.size
      end
    end
    assert_select "select[name*='media_platform_id']" do |selects|
      selects.each do |select|
        blanks = select.css("option").select { |option| option.text == "Select…" }
        assert_equal 1, blanks.size
      end
    end
  end

  test "authenticated user can view index" do
    get pr_records_path
    assert_response :success
    assert_select "a[aria-label='Log record'][style*=?]", "#465FFF"
    assert_no_match(/#c2410c/, response.body)
  end

  test "unauthenticated user redirected" do
    sign_out @user
    get pr_records_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "user without pr access is denied" do
    restricted_user = nil
    ActsAsTenant.with_tenant(@org) do
      restricted_role = Role.create!(name: "Restricted", slug: "restricted-#{Time.current.to_i}")
      restricted_user = User.create!(
        organization: @org,
        email: "restricted@example.com",
        password: "password",
        name: "Restricted User",
        role: restricted_role
      )
    end

    sign_out @user
    sign_in restricted_user
    get pr_records_path
    # Users without PR access are redirected to root
    assert_response :redirect
    assert_redirected_to root_path
  end

  test "index with category filter" do
    ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Electronic Coverage",
        entries_attributes: [ {
          published_on: Date.today,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform
        } ]
      )
    end

    get pr_records_path(category: @category.slug)
    assert_response :success
  end

  test "index shows each link on the row for its platform" do
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "Linked Coverage",
        entries_attributes: [ {
          published_on: Date.today,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform,
          url: "https://news.example/legacy"
        } ]
      )
      entry = record.entries.first
      entry.links.create!(url: "https://news.example/story", position: 0)
      entry.links.create!(url: "https://news.example/clip", position: 1)
    end

    get pr_records_path
    assert_response :success
    assert_select "th", text: "Links"
    assert_select "a[href='https://news.example/story'][target=_blank]", text: "news.example/story"
    assert_select "a[href='https://news.example/clip'][target=_blank]", text: "news.example/clip"
    assert_select "td", text: @platform.name
    assert_select "a[href='https://news.example/legacy']", count: 0
  end

  test "user can create record with owner set to current_user" do
    ActsAsTenant.with_tenant(@org) do
      post pr_records_path, params: {
        pr_record: {
          title: "New Coverage",
          entries_attributes: {
            "0" => {
              published_on: Date.today,
              sentiment: "positive",
              pr_category_id: @category.id,
              media_platform_id: @platform.id,
              description: "Test coverage"
            }
          }
        }
      }

      assert_response :redirect
      record = PrRecord.kept.order(created_at: :desc).first
      assert_equal @user.id, record.owner_id
      assert_equal "New Coverage", record.title
    end
  end

  test "media platform validation prevents invalid submission" do
    ActsAsTenant.with_tenant(@org) do
      post pr_records_path, params: {
        pr_record: {
          title: "Missing Platform",
          entries_attributes: {
            "0" => {
              published_on: Date.today,
              sentiment: "positive",
              pr_category_id: @category.id
            }
          }
        }
      }

      # Validation fails, returns form with errors
      assert_response :unprocessable_entity
    end
  end

  test "user can view their own record" do
    record = nil
    ActsAsTenant.with_tenant(@org) do
      record = @org.pr_records.create!(
        owner: @user,
        title: "My Record",
        entries_attributes: [ {
          published_on: Date.today,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform
        } ]
      )
    end

    get pr_record_path(record)
    assert_response :success
    assert_match "My Record", @response.body
  end

  test "user cannot view unrelated user's record (subtree restricted)" do
    other_user = nil
    record = nil
    ActsAsTenant.with_tenant(@org) do
      other_user = User.create!(
        organization: @org,
        email: "other@example.com",
        password: "password",
        name: "Other User",
        role: @member_role
      )
      record = @org.pr_records.create!(
        owner: other_user,
        title: "Other User Record",
        entries_attributes: [ {
          published_on: Date.today,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform
        } ]
      )
    end

    get pr_record_path(record)
    # Policy scope filters out records outside subtree, resulting in 404
    assert_response 404
  end

  # Org admin elevation is tested at policy layer via policy_scope and authorize checks.
  # Integration test would require proper tenant context throughout sign_in/sign_out transitions.

  test "cross-org isolation prevents access" do
    other_org = ActsAsTenant.without_tenant { Organization.create!(name: "Other Org") }
    other_record = nil

    ActsAsTenant.with_tenant(other_org) do
      role = Role.create!(
        name: "Member",
        slug: "member-other-#{Time.current.to_i}"
      )
      user = User.create!(
        organization: other_org,
        email: "other-org@example.com",
        password: "password",
        name: "Other Org User",
        role: role
      )
      category = PrCategory.find_or_create_by(slug: "electronic") do |c|
        c.name = "Electronic"
        c.active = true
      end
      platform = MediaPlatform.find_or_create_by(slug: "tv-news") do |p|
        p.name = "TV News"
        p.active = true
      end

      other_record = other_org.pr_records.create!(
        owner: user,
        title: "Other Org Record",
        entries_attributes: [ {
          published_on: Date.today,
          sentiment: :positive,
          pr_category: category,
          media_platform: platform
        } ]
      )
    end

    # Current user from @org tries to access @other_org's record
    get pr_record_path(other_record)
    assert_response 404
  end

  test "one headline can hold two categories" do
    print_category = PrCategory.find_by(slug: "print") || PrCategory.create!(
      name: "Print Media", slug: "print", active: true, display_order: 2
    )
    paper = MediaPlatform.create!(name: "Lokmat", slug: "lokmat-#{Time.current.to_i}", active: true, pr_category: print_category)

    post pr_records_path, params: {
      pr_record: {
        title: "Shared headline",
        entries_attributes: {
          "0" => {
            published_on: Date.today,
            sentiment: "positive",
            pr_category_id: @category.id,
            media_platform_id: @platform.id,
            description: "TV coverage"
          },
          "1" => {
            published_on: Date.today,
            sentiment: "neutral",
            pr_category_id: print_category.id,
            media_platform_id: paper.id,
            description: "Paper coverage"
          }
        }
      }
    }

    assert_response :redirect
    record = ActsAsTenant.with_tenant(@org) { PrRecord.kept.find_by!(title: "Shared headline") }
    assert_equal 2, record.entries.count
    assert_equal @user.id, record.owner_id

    get pr_record_path(record)
    assert_response :success
    assert_match "Shared headline", response.body
    assert_match "Where it appeared", response.body
    assert_match @category.name, response.body
    assert_match print_category.name, response.body

    get pr_records_path
    assert_match "Shared headline", response.body
    assert_select "td", text: @category.name
    assert_select "td", text: print_category.name
    assert_select "td", text: @platform.name
    assert_select "td", text: paper.name

    get pr_records_path(category: @category.slug)
    assert_match "Shared headline", response.body
    get pr_records_path(category: print_category.slug)
    assert_match "Shared headline", response.body
  end

  test "excel export lists each category and follows the category filter" do
    print_category = PrCategory.find_by(slug: "print") || PrCategory.create!(
      name: "Print Media", slug: "print", active: true, display_order: 2
    )
    paper = MediaPlatform.create!(name: "Sakal", slug: "sakal-#{Time.current.to_i}", active: true, pr_category: print_category)
    ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Export headline",
        entries_attributes: [
          { published_on: Date.current, sentiment: :positive, pr_category: @category, media_platform: @platform, url: "https://tv.example/story" },
          { published_on: Date.current, sentiment: :neutral, pr_category: print_category, media_platform: paper, url: "https://paper.example/story" }
        ]
      )
    end

    get pr_records_path(format: :xlsx)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
    assert_match "pr_records.xlsx", response.headers["Content-Disposition"]
    cells = xlsx_cells
    assert_includes cells, "Export headline"
    assert_includes cells, @category.name
    assert_includes cells, print_category.name
    assert_includes cells, "https://tv.example/story"

    get pr_records_path(format: :xlsx, category: print_category.slug)
    cells = xlsx_cells
    assert_includes cells, "Export headline"
    assert_includes cells, print_category.name
    assert_not_includes cells, @category.name
    assert_not_includes cells, "https://tv.example/story"
  end

  test "show page can delete one category after confirmation" do
    record, print_category = record_with_two_categories
    removed = ActsAsTenant.with_tenant(@org) { record.entries.find_by!(pr_category: print_category) }

    get pr_record_path(record)
    assert_response :success
    assert_select "#confirm-dialog[hidden] [data-confirm-accept]"
    assert_select "#confirm-dialog [data-confirm-cancel]", text: "Cancel"
    assert_select "button[aria-label=?][data-turbo-confirm=?]",
      I18n.t("pr.delete_category", name: print_category.name),
      I18n.t("pr.delete_category_named_confirm", name: print_category.name),
      count: 2

    assert_difference -> { ActsAsTenant.with_tenant(@org) { record.entries.count } }, -1 do
      delete pr_record_entry_path(record, removed)
    end
    assert_redirected_to pr_record_path(record)
    follow_redirect!
    assert_match I18n.t("pr.category_removed", name: print_category.name), response.body
    assert_select "button.action-icon-delete", count: 0
  end

  test "the only category on a record cannot be deleted" do
    record = ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Single category",
        entries_attributes: [ {
          published_on: Date.current,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform
        } ]
      )
    end

    get pr_record_path(record)
    assert_response :success
    assert_select "button.action-icon-delete", count: 0

    assert_no_difference -> { ActsAsTenant.with_tenant(@org) { record.entries.count } } do
      delete pr_record_entry_path(record, record.entries.first)
    end
    assert_redirected_to pr_record_path(record)
    follow_redirect!
    assert_match I18n.t("pr.last_category"), response.body
  end

  test "edit form puts a delete icon on every category" do
    record, = record_with_two_categories

    get edit_pr_record_path(record)
    assert_response :success
    ActsAsTenant.with_tenant(@org) do
      record.entries.each do |entry|
        assert_select "button.action-icon-delete[aria-label=?][data-confirm=?][data-destroy-url=?][data-action=?]",
          I18n.t("pr.remove_category"),
          I18n.t("pr.delete_category_confirm"),
          pr_record_entry_path(record, entry),
          "pr-record-form#removeEntry"
      end
    end
  end

  test "saving the form removes a category marked for deletion" do
    record, print_category = record_with_two_categories
    kept, removed = ActsAsTenant.with_tenant(@org) do
      [ record.entries.find_by!(pr_category: @category), record.entries.find_by!(pr_category: print_category) ]
    end

    patch pr_record_path(record), params: {
      pr_record: {
        title: record.title,
        entries_attributes: {
          "0" => { id: kept.id },
          "1" => { id: removed.id, _destroy: "1" }
        }
      }
    }

    assert_redirected_to pr_record_path(record)
    assert_equal [ kept.id ], ActsAsTenant.with_tenant(@org) { record.entries.reload.pluck(:id) }
  end

  test "show page can delete one link and keeps the others" do
    record = record_with_links
    entry = ActsAsTenant.with_tenant(@org) { record.entries.first }
    removed, kept = ActsAsTenant.with_tenant(@org) { entry.links.order(:id).to_a }

    get pr_record_path(record)
    assert_response :success
    assert_select "button[aria-label=?][data-turbo-confirm=?]",
      I18n.t("pr.delete_link"),
      I18n.t("pr.delete_link_confirm"),
      count: 2

    assert_difference -> { ActsAsTenant.with_tenant(@org) { entry.links.count } }, -1 do
      delete pr_record_entry_link_path(record, entry, removed)
    end
    assert_redirected_to pr_record_path(record)
    follow_redirect!
    assert_match I18n.t("pr.link_removed"), response.body
    assert_select "a[href='#{removed.url}']", count: 0
    assert_select "a[href='#{kept.url}']"
    assert_equal kept.url, ActsAsTenant.with_tenant(@org) { entry.reload.url }
  end

  test "deleting the last link clears it from the category" do
    record = record_with_links
    entry = ActsAsTenant.with_tenant(@org) { record.entries.first }
    links = ActsAsTenant.with_tenant(@org) { entry.links.order(:id).to_a }

    links.each do |link|
      delete pr_record_entry_link_path(record, entry, link)
      assert_redirected_to pr_record_path(record)
    end

    ActsAsTenant.with_tenant(@org) do
      entry.reload
      assert_empty entry.links
      assert_nil entry.url
      assert_nil entry.thumbnail_url
    end
    follow_redirect!
    assert_select "a[href='#{links.first.url}']", count: 0
    assert_select "a[href='#{links.last.url}']", count: 0
  end

  test "edit form puts a delete icon on every saved link" do
    record = record_with_links
    entry = ActsAsTenant.with_tenant(@org) { record.entries.first }

    get edit_pr_record_path(record)
    assert_response :success
    ActsAsTenant.with_tenant(@org) do
      entry.links.each do |link|
        assert_select "button.action-icon-delete[aria-label=?][data-confirm=?][data-destroy-url=?][data-action=?]",
          I18n.t("pr.delete_link"),
          I18n.t("pr.delete_link_confirm"),
          pr_record_entry_link_path(record, entry, link),
          "pr-record-form#removeLink"
      end
    end
  end

  test "a read-only user cannot delete a link" do
    record = record_with_links
    reader = ActsAsTenant.with_tenant(@org) do
      role = Role.create!(name: "Reader", slug: "link-reader-#{Time.current.to_i}")
      role.role_permissions.create!(module_name: "pr", access_level: "read")
      user = User.create!(
        organization: @org,
        email: "link-reader-#{Time.current.to_i}@example.com",
        password: "password",
        name: "Reader",
        role: role
      )
      record.update!(owner: user)
      user
    end
    entry = ActsAsTenant.with_tenant(@org) { record.entries.first }
    link = ActsAsTenant.with_tenant(@org) { entry.links.order(:id).first }

    sign_in reader
    get pr_record_path(record)
    assert_response :success
    assert_select "button[aria-label=?]", I18n.t("pr.delete_link"), count: 0

    assert_no_difference -> { ActsAsTenant.with_tenant(@org) { entry.links.count } } do
      delete pr_record_entry_link_path(record, entry, link)
    end
    assert_response :not_found
  end

  test "a read-only user cannot delete a category" do
    record, print_category = record_with_two_categories
    reader = ActsAsTenant.with_tenant(@org) do
      role = Role.create!(name: "Reader", slug: "reader-#{Time.current.to_i}")
      role.role_permissions.create!(module_name: "pr", access_level: "read")
      user = User.create!(
        organization: @org,
        email: "reader-#{Time.current.to_i}@example.com",
        password: "password",
        name: "Reader",
        role: role
      )
      record.update!(owner: user)
      user
    end
    removed = ActsAsTenant.with_tenant(@org) { record.entries.find_by!(pr_category: print_category) }

    sign_in reader
    get pr_record_path(record)
    assert_response :success
    assert_select "button.action-icon-delete", count: 0

    assert_no_difference -> { ActsAsTenant.with_tenant(@org) { record.entries.count } } do
      delete pr_record_entry_path(record, removed)
    end
    assert_response :not_found
  end

  def record_with_links
    ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Linked story",
        entries_attributes: [ {
          published_on: Date.current,
          sentiment: :positive,
          pr_category: @category,
          media_platform: @platform,
          links_attributes: [
            { url: "https://news.example/story", thumbnail_url: "https://news.example/story.jpg" },
            { url: "https://news.example/clip" }
          ]
        } ]
      )
    end
  end

  def record_with_two_categories
    print_category = PrCategory.find_by(slug: "print") || PrCategory.create!(
      name: "Print Media", slug: "print", active: true, display_order: 2
    )
    paper = MediaPlatform.create!(
      name: "Lokmat",
      slug: "lokmat-#{SecureRandom.hex(4)}",
      active: true,
      pr_category: print_category
    )
    record = ActsAsTenant.with_tenant(@org) do
      @org.pr_records.create!(
        owner: @user,
        title: "Two categories",
        entries_attributes: [
          { published_on: Date.current, sentiment: :positive, pr_category: @category, media_platform: @platform },
          { published_on: Date.current, sentiment: :neutral, pr_category: print_category, media_platform: paper }
        ]
      )
    end
    [ record, print_category ]
  end

  def xlsx_cells
    file = Tempfile.new([ "export", ".xlsx" ])
    file.binmode
    file.write(@response.body)
    file.rewind
    Roo::Excelx.new(file.path).sheet(0).to_a.flatten.map(&:to_s)
  ensure
    file&.close
  end
end
