module Console
  class AdminContactRolesController < ReferenceController
    self.managed_model = AdminContactRole
    self.managed_fields = %i[name active]
    self.managed_title = "Administrative role"
  end
end
