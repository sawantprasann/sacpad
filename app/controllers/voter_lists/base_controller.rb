module VoterLists
  # Talukas and villages this organization's constituency actually covers.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_voter_access

    private

    def require_voter_access
      return if current_user.role.can_access?("voter_lists")

      redirect_to root_path, alert: t("voters_access.no_access")
    end

    def organization_villages
      current_user.visible_villages(current_user.organization.villages)
    end

    def organization_talukas
      Taluka.where(id: organization_villages.where.not(taluka_id: nil).select(:taluka_id))
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end
  end
end
