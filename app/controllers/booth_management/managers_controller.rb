module BoothManagement
  # A booth manager is created from the booth page and can open only that booth's voter list.
  class ManagersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_booth_access
    before_action :set_booth
    before_action :require_booth_manager_creator

    def create
      role = Role.find_by!(slug: "booth_manager")
      manager = current_user.organization.users.new(manager_params)
      manager.role = role
      manager.booth = @booth
      manager.parent = current_user
      if manager.save
        redirect_to booth_path(@booth), notice: t("booths.manager_added", name: manager.name, number: @booth.number)
      else
        redirect_to booth_path(@booth), alert: manager.errors.full_messages.to_sentence
      end
    end

    private

    def set_booth
      @booth = Booth.where(village_id: current_user.organization.villages.select(:id)).find(params[:booth_id])
    end

    def manager_params
      params.require(:user).permit(:name, :email, :phone, :password)
    end

    def require_booth_access
      return if current_user.role.can_access?("booth_management")

      redirect_to root_path, alert: t("booths.no_access")
    end

    def require_booth_manager_creator
      return if current_user.can_add_booth_manager?

      redirect_to booth_path(@booth), alert: t("booths.only_admin")
    end
  end
end
