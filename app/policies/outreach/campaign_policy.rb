module Outreach
  class CampaignPolicy < ApplicationPolicy
    def index? = user.role.can_access?("social_media")
    def show? = index?
    def create? = user.role.slug.in?(%w[org_admin pa manager])
    def send_messages? = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(created_at: :desc)
      end
    end
  end
end
