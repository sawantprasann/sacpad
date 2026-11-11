module SocialMedia
  class SocialPagePolicy < ApplicationPolicy
    def index? = user.role.can_access?("social_media")
    def show? = index?

    # Connecting and disconnecting a Page is the org admin's job.
    def connect? = user.role.slug == "org_admin"
    def create? = connect?
    def destroy? = connect?

    # Org Admin, PA, and Manager write posts. Connecting stays with the admin.
    def publish? = user.role.slug.in?(%w[org_admin pa manager])

    # Pages belong to the organization. Anyone who can open Social Media sees them.
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.kept
      end
    end
  end
end
