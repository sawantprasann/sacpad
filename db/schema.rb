# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_080000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activity_logs", force: :cascade do |t|
    t.string "actor_type", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.string "record_type"
    t.bigint "record_id"
    t.bigint "organization_id"
    t.datetime "created_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_activity_logs_on_actor"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["organization_id"], name: "index_activity_logs_on_organization_id"
    t.index ["record_type", "record_id"], name: "index_activity_logs_on_record"
  end

  create_table "admin_organizations", force: :cascade do |t|
    t.bigint "admin_id", null: false
    t.bigint "organization_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id", "organization_id"], name: "index_admin_organizations_on_admin_id_and_organization_id", unique: true
    t.index ["admin_id"], name: "index_admin_organizations_on_admin_id"
    t.index ["organization_id"], name: "index_admin_organizations_on_organization_id"
  end

  create_table "admins", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "tier", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "assemblies", force: :cascade do |t|
    t.bigint "loksabha_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "taluka_id"
    t.string "constituency_no"
    t.index ["loksabha_id"], name: "index_assemblies_on_loksabha_id"
    t.index ["taluka_id"], name: "index_assemblies_on_taluka_id"
  end

  create_table "booths", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.string "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["village_id"], name: "index_booths_on_village_id"
  end

  create_table "cadre_activities", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.bigint "organization_id", null: false
    t.integer "category", null: false
    t.text "impact_notes"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_cadre_activities_on_category"
    t.index ["discarded_at"], name: "index_cadre_activities_on_discarded_at"
    t.index ["organization_id", "owner_id"], name: "index_cadre_activities_on_organization_id_and_owner_id"
    t.index ["organization_id"], name: "index_cadre_activities_on_organization_id"
    t.index ["owner_id"], name: "index_cadre_activities_on_owner_id"
  end

  create_table "cadre_activity_leadership_meets", force: :cascade do |t|
    t.bigint "cadre_activity_id", null: false
    t.bigint "organization_id", null: false
    t.string "whom_to_meet", null: false
    t.text "point_of_discussion"
    t.text "work_submitted"
    t.date "submitted_on"
    t.date "followup_on"
    t.text "resolution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cadre_activity_id"], name: "index_cadre_activity_leadership_meets_on_cadre_activity_id", unique: true
    t.index ["organization_id"], name: "index_cadre_activity_leadership_meets_on_organization_id"
  end

  create_table "cadre_activity_one_to_ones", force: :cascade do |t|
    t.bigint "cadre_activity_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "karyakarta_user_id"
    t.string "karyakarta_name_text"
    t.string "assignment"
    t.boolean "resolved", default: false, null: false
    t.date "from_date"
    t.date "to_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cadre_activity_id"], name: "index_cadre_activity_one_to_ones_on_cadre_activity_id", unique: true
    t.index ["karyakarta_user_id"], name: "index_cadre_activity_one_to_ones_on_karyakarta_user_id"
    t.index ["organization_id"], name: "index_cadre_activity_one_to_ones_on_organization_id"
  end

  create_table "cadre_activity_party_program_hosteds", force: :cascade do |t|
    t.bigint "cadre_activity_id", null: false
    t.bigint "organization_id", null: false
    t.string "program_name", null: false
    t.date "hosted_on"
    t.string "location"
    t.integer "total_attendees"
    t.string "print_media"
    t.string "electronic_media"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cadre_activity_id"], name: "idx_on_cadre_activity_id_3c508384a4", unique: true
    t.index ["organization_id"], name: "index_cadre_activity_party_program_hosteds_on_organization_id"
  end

  create_table "cadre_activity_personal_activities", force: :cascade do |t|
    t.bigint "cadre_activity_id", null: false
    t.bigint "organization_id", null: false
    t.string "activity_name", null: false
    t.string "occasion"
    t.string "total_submission"
    t.date "from_date"
    t.date "to_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cadre_activity_id"], name: "index_cadre_activity_personal_activities_on_cadre_activity_id", unique: true
    t.index ["organization_id"], name: "index_cadre_activity_personal_activities_on_organization_id"
  end

  create_table "cadre_activity_programs", force: :cascade do |t|
    t.bigint "cadre_activity_id", null: false
    t.bigint "organization_id", null: false
    t.string "program_name", null: false
    t.string "occasion"
    t.string "location"
    t.date "occurred_on"
    t.string "host"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cadre_activity_id"], name: "index_cadre_activity_programs_on_cadre_activity_id", unique: true
    t.index ["organization_id"], name: "index_cadre_activity_programs_on_organization_id"
  end

  create_table "districts", force: :cascade do |t|
    t.bigint "state_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cd"
    t.index ["state_id"], name: "index_districts_on_state_id"
  end

  create_table "ground_report_imports", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.integer "kind", null: false
    t.integer "status", default: 0, null: false
    t.integer "imported_count", default: 0, null: false
    t.jsonb "row_errors", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_ground_report_imports_on_organization_id"
    t.index ["user_id"], name: "index_ground_report_imports_on_user_id"
  end

  create_table "ground_report_testimonials", force: :cascade do |t|
    t.bigint "ground_report_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "created_by_id", null: false
    t.string "person_name", null: false
    t.integer "content_type", null: false
    t.text "text_content"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_ground_report_testimonials_on_created_by_id"
    t.index ["discarded_at"], name: "index_ground_report_testimonials_on_discarded_at"
    t.index ["ground_report_id"], name: "index_ground_report_testimonials_on_ground_report_id"
    t.index ["organization_id"], name: "index_ground_report_testimonials_on_organization_id"
  end

  create_table "ground_reports", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "village_id", null: false
    t.text "issue_text", null: false
    t.text "resolution_text"
    t.date "reported_at", null: false
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_ground_reports_on_discarded_at"
    t.index ["organization_id", "owner_id"], name: "index_ground_reports_on_organization_id_and_owner_id"
    t.index ["organization_id", "village_id"], name: "index_ground_reports_on_organization_id_and_village_id"
    t.index ["organization_id"], name: "index_ground_reports_on_organization_id"
    t.index ["owner_id"], name: "index_ground_reports_on_owner_id"
    t.index ["village_id"], name: "index_ground_reports_on_village_id"
  end

  create_table "loksabhas", force: :cascade do |t|
    t.bigint "state_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "district_id"
    t.string "constituency_no"
    t.index ["district_id"], name: "index_loksabhas_on_district_id"
    t.index ["state_id"], name: "index_loksabhas_on_state_id"
  end

  create_table "media_platforms", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_media_platforms_on_slug", unique: true
  end

  create_table "mock_poll_responses", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "politician_id", null: false
    t.bigint "created_by_id", null: false
    t.string "respondent_name", null: false
    t.string "respondent_mobile"
    t.integer "preference_basis", null: false
    t.boolean "vote_intent"
    t.text "note"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_mock_poll_responses_on_created_by_id"
    t.index ["discarded_at"], name: "index_mock_poll_responses_on_discarded_at"
    t.index ["organization_id", "village_id", "politician_id"], name: "index_mock_poll_responses_on_org_village_politician"
    t.index ["organization_id"], name: "index_mock_poll_responses_on_organization_id"
    t.index ["politician_id"], name: "index_mock_poll_responses_on_politician_id"
    t.index ["village_id"], name: "index_mock_poll_responses_on_village_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.bigint "current_party_id"
    t.string "constituency_type"
    t.bigint "constituency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["constituency_type", "constituency_id"], name: "index_organizations_on_constituency"
  end

  create_table "outdoor_ad_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_outdoor_ad_types_on_slug", unique: true
  end

  create_table "parties", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "party_memberships", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "party_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_party_memberships_on_organization_id"
    t.index ["party_id"], name: "index_party_memberships_on_party_id"
  end

  create_table "politicians", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.bigint "party_id"
    t.boolean "is_own_politician", default: false, null: false
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_politicians_on_discarded_at"
    t.index ["organization_id"], name: "index_politicians_on_organization_id"
    t.index ["organization_id"], name: "one_own_politician_per_org", unique: true, where: "(is_own_politician = true)"
    t.index ["party_id"], name: "index_politicians_on_party_id"
  end

  create_table "pr_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "display_order", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_pr_categories_on_slug", unique: true
  end

  create_table "pr_record_outdoor_ad_counts", force: :cascade do |t|
    t.bigint "pr_record_id", null: false
    t.bigint "outdoor_ad_type_id", null: false
    t.integer "count", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pr_record_id", "outdoor_ad_type_id"], name: "idx_on_pr_record_id_outdoor_ad_type_id_5cdb583466", unique: true
  end

  create_table "pr_record_podcasts", force: :cascade do |t|
    t.bigint "pr_record_id", null: false
    t.date "recording_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pr_record_id"], name: "index_pr_record_podcasts_on_pr_record_id", unique: true
  end

  create_table "pr_records", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "owner_id", null: false
    t.bigint "pr_category_id", null: false
    t.bigint "media_platform_id"
    t.string "record_number", null: false
    t.string "title", null: false
    t.text "description"
    t.string "url"
    t.string "thumbnail_url"
    t.integer "sentiment", default: 0, null: false
    t.date "published_on", null: false
    t.string "media_platform_name"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_pr_records_on_discarded_at"
    t.index ["discarded_by_id"], name: "index_pr_records_on_discarded_by_id"
    t.index ["media_platform_id"], name: "index_pr_records_on_media_platform_id"
    t.index ["organization_id", "record_number"], name: "index_pr_records_on_organization_id_and_record_number", unique: true
    t.index ["organization_id"], name: "index_pr_records_on_organization_id"
    t.index ["owner_id"], name: "index_pr_records_on_owner_id"
    t.index ["pr_category_id"], name: "index_pr_records_on_pr_category_id"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.integer "module_name", null: false
    t.integer "access_level", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "module_name"], name: "index_role_permissions_on_role_id_and_module_name", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "is_system", default: false, null: false
    t.boolean "can_create_users", default: false, null: false
    t.bigint "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "can_import", default: false, null: false
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "states", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cd"
  end

  create_table "talukas", force: :cascade do |t|
    t.bigint "district_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id"], name: "index_talukas_on_district_id"
  end

  create_table "ticket_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "active", default: true, null: false
    t.integer "display_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_ticket_categories_on_display_order"
    t.index ["slug"], name: "index_ticket_categories_on_slug", unique: true
  end

  create_table "ticket_follow_ups", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "created_by_id", null: false
    t.text "note", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_ticket_follow_ups_on_created_by_id"
    t.index ["organization_id"], name: "index_ticket_follow_ups_on_organization_id"
    t.index ["ticket_id"], name: "index_ticket_follow_ups_on_ticket_id"
  end

  create_table "ticket_status_changes", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "actor_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_ticket_status_changes_on_actor_id"
    t.index ["organization_id"], name: "index_ticket_status_changes_on_organization_id"
    t.index ["ticket_id"], name: "index_ticket_status_changes_on_ticket_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "ticket_category_id", null: false
    t.string "ticket_number"
    t.string "person_name", null: false
    t.string "village"
    t.string "mobile"
    t.text "description"
    t.date "reported_at", null: false
    t.datetime "closed_at"
    t.string "voter_id"
    t.string "nature_of_issue"
    t.decimal "reported_value", precision: 12, scale: 2
    t.integer "status", default: 0, null: false
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_tickets_on_discarded_at"
    t.index ["organization_id", "ticket_number"], name: "index_tickets_on_organization_id_and_ticket_number", unique: true
    t.index ["organization_id"], name: "index_tickets_on_organization_id"
    t.index ["owner_id"], name: "index_tickets_on_owner_id"
    t.index ["ticket_category_id"], name: "index_tickets_on_ticket_category_id"
  end

  create_table "user_hierarchies", id: false, force: :cascade do |t|
    t.bigint "ancestor_id", null: false
    t.bigint "descendant_id", null: false
    t.integer "generations", null: false
    t.index ["ancestor_id", "descendant_id", "generations"], name: "user_anc_desc_idx", unique: true
    t.index ["descendant_id"], name: "user_desc_idx"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "parent_id"
    t.bigint "role_id", null: false
    t.string "name", default: "", null: false
    t.string "phone"
    t.boolean "active", default: true, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["parent_id"], name: "index_users_on_parent_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "village_local_admin_contacts", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "role_title", null: false
    t.string "phone"
    t.text "notes"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_village_local_admin_contacts_on_discarded_at"
    t.index ["organization_id", "village_id"], name: "idx_on_organization_id_village_id_9698e53fd0"
    t.index ["organization_id"], name: "index_village_local_admin_contacts_on_organization_id"
    t.index ["village_id"], name: "index_village_local_admin_contacts_on_village_id"
  end

  create_table "village_local_karyakartas", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "phone"
    t.text "notes"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_village_local_karyakartas_on_discarded_at"
    t.index ["organization_id", "village_id"], name: "idx_on_organization_id_village_id_4a876deaf0"
    t.index ["organization_id"], name: "index_village_local_karyakartas_on_organization_id"
    t.index ["village_id"], name: "index_village_local_karyakartas_on_village_id"
  end

  create_table "village_political_positions", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "party_id", null: false
    t.string "representative_name", null: false
    t.string "position_title", null: false
    t.date "started_at", null: false
    t.date "ended_at"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_village_political_positions_on_discarded_at"
    t.index ["organization_id"], name: "index_village_political_positions_on_organization_id"
    t.index ["party_id"], name: "index_village_political_positions_on_party_id"
    t.index ["village_id", "organization_id"], name: "one_current_position_per_village_org", unique: true, where: "((ended_at IS NULL) AND (discarded_at IS NULL))"
    t.index ["village_id"], name: "index_village_political_positions_on_village_id"
  end

  create_table "village_yatras", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "updated_by_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_village_yatras_on_organization_id"
    t.index ["updated_by_id"], name: "index_village_yatras_on_updated_by_id"
    t.index ["village_id", "organization_id"], name: "index_village_yatras_on_village_id_and_organization_id", unique: true
    t.index ["village_id"], name: "index_village_yatras_on_village_id"
  end

  create_table "villages", force: :cascade do |t|
    t.bigint "assembly_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assembly_id"], name: "index_villages_on_assembly_id"
  end

  create_table "voter_versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_voter_versions_on_item_type_and_item_id"
  end

  create_table "voters", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "booth_id"
    t.string "state"
    t.string "loksabha"
    t.string "assembly"
    t.string "village"
    t.text "voter_id"
    t.text "name"
    t.text "mobile"
    t.integer "sentiment_status"
    t.bigint "sentiment_updated_by_id"
    t.datetime "sentiment_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booth_id"], name: "index_voters_on_booth_id"
    t.index ["organization_id"], name: "index_voters_on_organization_id"
  end

  create_table "worship_places", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "place_type", null: false
    t.text "notes"
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_worship_places_on_discarded_at"
    t.index ["organization_id", "village_id"], name: "index_worship_places_on_organization_id_and_village_id"
    t.index ["organization_id"], name: "index_worship_places_on_organization_id"
    t.index ["village_id"], name: "index_worship_places_on_village_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_organizations", "admins"
  add_foreign_key "admin_organizations", "organizations"
  add_foreign_key "assemblies", "loksabhas"
  add_foreign_key "assemblies", "talukas"
  add_foreign_key "booths", "villages"
  add_foreign_key "cadre_activities", "organizations"
  add_foreign_key "cadre_activities", "users", column: "owner_id"
  add_foreign_key "cadre_activity_leadership_meets", "cadre_activities"
  add_foreign_key "cadre_activity_leadership_meets", "organizations"
  add_foreign_key "cadre_activity_one_to_ones", "cadre_activities"
  add_foreign_key "cadre_activity_one_to_ones", "organizations"
  add_foreign_key "cadre_activity_one_to_ones", "users", column: "karyakarta_user_id"
  add_foreign_key "cadre_activity_party_program_hosteds", "cadre_activities"
  add_foreign_key "cadre_activity_party_program_hosteds", "organizations"
  add_foreign_key "cadre_activity_personal_activities", "cadre_activities"
  add_foreign_key "cadre_activity_personal_activities", "organizations"
  add_foreign_key "cadre_activity_programs", "cadre_activities"
  add_foreign_key "cadre_activity_programs", "organizations"
  add_foreign_key "districts", "states"
  add_foreign_key "ground_report_imports", "organizations"
  add_foreign_key "ground_report_imports", "users"
  add_foreign_key "ground_report_testimonials", "ground_reports"
  add_foreign_key "ground_report_testimonials", "organizations"
  add_foreign_key "ground_report_testimonials", "users", column: "created_by_id"
  add_foreign_key "ground_reports", "organizations"
  add_foreign_key "ground_reports", "users", column: "owner_id"
  add_foreign_key "ground_reports", "villages"
  add_foreign_key "loksabhas", "districts"
  add_foreign_key "loksabhas", "states"
  add_foreign_key "mock_poll_responses", "organizations"
  add_foreign_key "mock_poll_responses", "politicians"
  add_foreign_key "mock_poll_responses", "users", column: "created_by_id"
  add_foreign_key "mock_poll_responses", "villages"
  add_foreign_key "party_memberships", "organizations"
  add_foreign_key "party_memberships", "parties"
  add_foreign_key "politicians", "organizations"
  add_foreign_key "politicians", "parties"
  add_foreign_key "pr_record_outdoor_ad_counts", "outdoor_ad_types"
  add_foreign_key "pr_record_outdoor_ad_counts", "pr_records"
  add_foreign_key "pr_record_podcasts", "pr_records"
  add_foreign_key "pr_records", "media_platforms"
  add_foreign_key "pr_records", "organizations"
  add_foreign_key "pr_records", "pr_categories"
  add_foreign_key "pr_records", "users", column: "discarded_by_id"
  add_foreign_key "pr_records", "users", column: "owner_id"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "roles", "organizations"
  add_foreign_key "talukas", "districts"
  add_foreign_key "ticket_follow_ups", "organizations"
  add_foreign_key "ticket_follow_ups", "tickets"
  add_foreign_key "ticket_follow_ups", "users", column: "created_by_id"
  add_foreign_key "ticket_status_changes", "organizations"
  add_foreign_key "ticket_status_changes", "tickets"
  add_foreign_key "ticket_status_changes", "users", column: "actor_id"
  add_foreign_key "tickets", "organizations"
  add_foreign_key "tickets", "ticket_categories"
  add_foreign_key "tickets", "users", column: "owner_id"
  add_foreign_key "users", "organizations"
  add_foreign_key "users", "roles"
  add_foreign_key "users", "users", column: "parent_id"
  add_foreign_key "village_local_admin_contacts", "organizations"
  add_foreign_key "village_local_admin_contacts", "villages"
  add_foreign_key "village_local_karyakartas", "organizations"
  add_foreign_key "village_local_karyakartas", "villages"
  add_foreign_key "village_political_positions", "organizations"
  add_foreign_key "village_political_positions", "parties"
  add_foreign_key "village_political_positions", "villages"
  add_foreign_key "village_yatras", "organizations"
  add_foreign_key "village_yatras", "users", column: "updated_by_id"
  add_foreign_key "village_yatras", "villages"
  add_foreign_key "villages", "assemblies"
  add_foreign_key "voters", "booths"
  add_foreign_key "voters", "organizations"
  add_foreign_key "worship_places", "organizations"
  add_foreign_key "worship_places", "villages"
end
