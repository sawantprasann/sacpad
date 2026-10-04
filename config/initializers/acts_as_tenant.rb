# Tenant isolation, layer 3 of the defense-in-depth spine (architecture §Core Decisions).
# require_tenant = true makes any query on a tenant-scoped model RAISE
# (ActsAsTenant::Errors::NoTenantSet) when no current organization is set, instead of
# silently returning unscoped rows. Cross-org/admin paths must wrap work in
# `ActsAsTenant.without_tenant { ... }` deliberately (Admin console, seeds, migrations).
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
