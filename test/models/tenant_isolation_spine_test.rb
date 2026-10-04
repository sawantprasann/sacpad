require "test_helper"
require_relative "../support/tenant_isolation"

# Story 0.2 — proves the tenant-isolation spine (acts_as_tenant + OrganizationScoped +
# require_tenant) actually isolates, using a self-contained probe model so we don't depend
# on any domain model (those land in later stories).
class TenantIsolationSpineTest < ActiveSupport::TestCase
  include TenantIsolation

  class ProbeRecord < ApplicationRecord
    self.table_name = "tenant_probe_records"
    include OrganizationScoped
  end

  setup do
    ActiveRecord::Base.connection.create_table :tenant_probe_records, force: true do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :label
      t.timestamps
    end
    ProbeRecord.reset_column_information

    ActsAsTenant.without_tenant do
      @org_a = Organization.create!(name: "Org A")
      @org_b = Organization.create!(name: "Org B")
      @a_row = ProbeRecord.create!(organization: @org_a, label: "a")
      @b_row = ProbeRecord.create!(organization: @org_b, label: "b")
    end
  end

  teardown do
    ActiveRecord::Base.connection.drop_table :tenant_probe_records, if_exists: true
  end

  test "a query on a tenant-scoped model with no tenant set raises" do
    assert_raises_without_tenant(ProbeRecord)
  end

  test "queries auto-scope to the current organization" do
    ActsAsTenant.with_tenant(@org_a) { assert_equal [ @a_row.id ], ProbeRecord.pluck(:id) }
    ActsAsTenant.with_tenant(@org_b) { assert_equal [ @b_row.id ], ProbeRecord.pluck(:id) }
  end

  test "Org A cannot read/update/delete an Org B record" do
    assert_tenant_isolated(ProbeRecord, owner: @org_a, foreign_record: @b_row)
  end

  test "organization_id presence is enforced" do
    ActsAsTenant.without_tenant do
      record = ProbeRecord.new(label: "orphan")
      assert_not record.valid?
      assert_includes record.errors.attribute_names, :organization_id
    end
  end
end
