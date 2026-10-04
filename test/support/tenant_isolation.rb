# Reusable cross-tenant isolation assertions (FR11 / NFR3).
# Every tenant-scoped model gets an isolation test using these helpers; a missing
# isolation test is a release blocker. The contract: a record owned by another
# organization is NOT found (→ 404, never a 403 that would confirm existence),
# and a query with no tenant set RAISES rather than returning unscoped rows.
module TenantIsolation
  # owner: the Organization we are "logged in" as.
  # foreign_record: a persisted record belonging to a DIFFERENT organization.
  def assert_tenant_isolated(model, owner:, foreign_record:)
    ActsAsTenant.with_tenant(owner) do
      assert_raises(ActiveRecord::RecordNotFound, "cross-tenant find must raise (→ 404)") do
        model.find(foreign_record.id)
      end
      refute_includes model.pluck(:id), foreign_record.id,
        "cross-tenant row must not appear in scoped listings"
      assert_equal 0, model.where(id: foreign_record.id).update_all(updated_at: Time.current),
        "cross-tenant update must affect 0 rows"
      assert_equal 0, model.where(id: foreign_record.id).delete_all,
        "cross-tenant delete must affect 0 rows"
    end
  end

  def assert_raises_without_tenant(model)
    assert_raises(ActsAsTenant::Errors::NoTenantSet, "unscoped query must raise") do
      model.count
    end
  end
end
