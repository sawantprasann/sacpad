module GroundReports
  class LocalAdminContactsController < ApplicationController
    include LoadsVillage

    before_action :set_contact, only: %i[edit update destroy]
    before_action :load_roles, only: %i[edit update]

    def create
      contact = @village.local_admin_contacts.new(contact_params)
      contact.organization = current_user.organization
      authorize contact
      if contact.save
        redirect_to ground_reports_village_path(@village), notice: "Administrative contact added."
      else
        redirect_to ground_reports_village_path(@village), alert: contact.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @contact.update(contact_params)
        redirect_to ground_reports_village_path(@village), notice: "Administrative contact updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @contact.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: "Administrative contact deleted."
    end

    private

    def set_contact
      @contact = @village.local_admin_contacts.kept.find(params[:id])
      authorize @contact
    end

    def load_roles
      @admin_roles = AdminContactRole.active
    end

    def contact_params
      params.require(:village_local_admin_contact).permit(:name, :role_title, :admin_contact_role_id, :phone, :notes)
    end
  end
end
