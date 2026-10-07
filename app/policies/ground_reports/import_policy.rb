module GroundReports
  class ImportPolicy < ApplicationPolicy
    def index?  = importer?
    def show?   = record.user_id == user.id && (importer? || mock_poll_writer?)
    def create? = importer? || mock_poll_writer?
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(user_id: user.id)
      end
    end

    private

    def importer?
      user.role.can_import? && user.role.can_access?("ground_reports")
    end

    # Anyone who can record a response can upload a mock-poll sheet.
    # Report import stays limited to the import capability.
    def mock_poll_writer?
      user.role.can_write?("ground_reports") && record.respond_to?(:mock_poll?) && record.mock_poll?
    end
  end
end
