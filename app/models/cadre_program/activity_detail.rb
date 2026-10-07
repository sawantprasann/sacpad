module CadreProgram
  # Shared bits for a per-category detail row (Story 2.2). The parent CadreActivity is what
  # scoping and the feed key off; the detail still carries organization_id so a direct query
  # cannot leak across tenants.
  module ActivityDetail
    extend ActiveSupport::Concern

    included do
      include OrganizationScoped
      belongs_to :cadre_activity, class_name: "CadreProgram::CadreActivity"
      before_validation :copy_organization_from_activity
    end

    private

    def copy_organization_from_activity
      self.organization_id ||= cadre_activity&.organization_id
    end
  end
end
