module GroundReports
  class ImportPolicy < ApplicationPolicy
    def index?  = user.role.can_import? && user.role.can_access?("ground_reports")
    def show?   = index? && record.user_id == user.id
    def create? = index?
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(user_id: user.id)
      end
    end
  end
end
