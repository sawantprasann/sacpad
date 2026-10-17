module BoothManagement
  class ChecklistItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_booth_write
    before_action :set_booth

    def create
      item = BoothChecklistItem.new(booth: @booth, organization: current_user.organization, label: params.dig(:booth_checklist_item, :label))
      if item.save
        redirect_to booth_path(@booth), notice: "Checklist item added."
      else
        redirect_to booth_path(@booth), alert: item.errors.full_messages.to_sentence
      end
    end

    def update
      item = BoothChecklistItem.find_by!(id: params[:id], booth: @booth)
      item.update!(done: !item.done)
      redirect_to booth_path(@booth)
    end

    private

    def set_booth
      @booth = Booth.where(village_id: current_user.organization.villages.select(:id)).find(params[:booth_id])
    end

    def require_booth_write
      return if current_user.role.can_write?("booth_management")

      redirect_to root_path, alert: "You can't update booth checklists."
    end
  end
end
