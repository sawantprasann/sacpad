module GroundReports
  class VillageYatraPolicy < ApplicationPolicy
    def show?   = user.role.can_access?("ground_reports")
    def update? = user.role.can_write?("ground_reports")

    class Scope < ApplicationPolicy::Scope
      def resolve = scope.all
    end
  end
end
