module GroundReports
  class VillageLocalAdminContactPolicy < ApplicationPolicy
    def index?  = user.role.can_access?("ground_reports")
    def show?   = index?
    def create? = user.role.can_write?("ground_reports")

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
