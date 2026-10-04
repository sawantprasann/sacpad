require "test_helper"

class AuditFrameworkTest < ActiveSupport::TestCase
  # --- ActivityLog ---
  test "ActivityLog.record! writes an append-only entry" do
    admin = Admin.create!(name: "Dev", email: "dev@example.com", password: "password123")
    log = ActivityLog.record!(actor: admin, action: "org.viewed")
    assert_equal admin, log.actor
    assert_equal "org.viewed", log.action
    assert_not_nil log.created_at
  end

  test "ActivityLog derives organization_id from the record when not given" do
    org = ActsAsTenant.without_tenant { Organization.create!(name: "Org A") }
    role = Role.create!(name: "Org Admin", slug: "org_admin")
    user = User.create!(organization: org, role: role, name: "Meera",
                        email: "meera@example.com", password: "password123")
    log = ActivityLog.record!(actor: user, action: "user.created", record: user)
    assert_equal org.id, log.organization_id
  end

  # --- SoftDeletable (probe model) ---
  class ProbeDeletable < ApplicationRecord
    self.table_name = "probe_deletables"
    include SoftDeletable
  end

  setup do
    ActiveRecord::Base.connection.create_table :probe_deletables, force: true do |t|
      t.string :label
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    ProbeDeletable.reset_column_information
  end

  teardown { ActiveRecord::Base.connection.drop_table :probe_deletables, if_exists: true }

  test "SoftDeletable discards without hard-deleting and records who" do
    admin = Admin.create!(name: "Dev", email: "dev2@example.com", password: "password123")
    row = ProbeDeletable.create!(label: "x")

    row.discard_by(admin)
    assert row.discarded?
    assert_equal admin.id, row.discarded_by_id
    assert_includes ProbeDeletable.discarded, row
    assert_not_includes ProbeDeletable.kept, row
    assert ProbeDeletable.exists?(row.id), "row must still exist (soft delete, not hard delete)"
  end
end
