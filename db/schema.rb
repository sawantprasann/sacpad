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

ActiveRecord::Schema[8.1].define(version: 2026_10_04_151012) do
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
    t.index ["loksabha_id"], name: "index_assemblies_on_loksabha_id"
  end

  create_table "booths", force: :cascade do |t|
    t.bigint "village_id", null: false
    t.string "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["village_id"], name: "index_booths_on_village_id"
  end

  create_table "loksabhas", force: :cascade do |t|
    t.bigint "state_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state_id"], name: "index_loksabhas_on_state_id"
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
    t.index ["organization_id"], name: "index_roles_on_organization_id"
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "states", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_organizations", "admins"
  add_foreign_key "admin_organizations", "organizations"
  add_foreign_key "assemblies", "loksabhas"
  add_foreign_key "booths", "villages"
  add_foreign_key "loksabhas", "states"
  add_foreign_key "party_memberships", "organizations"
  add_foreign_key "party_memberships", "parties"
  add_foreign_key "politicians", "organizations"
  add_foreign_key "politicians", "parties"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "roles", "organizations"
  add_foreign_key "users", "organizations"
  add_foreign_key "users", "roles"
  add_foreign_key "users", "users", column: "parent_id"
  add_foreign_key "villages", "assemblies"
  add_foreign_key "voters", "booths"
  add_foreign_key "voters", "organizations"
end
