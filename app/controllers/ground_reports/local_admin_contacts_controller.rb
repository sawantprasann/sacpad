module GroundReports
  class LocalAdminContactsController < ApplicationController
    include LoadsVillage

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

    private

    def contact_params
      params.require(:village_local_admin_contact).permit(:name, :role_title, :phone, :notes)
    end
  end
end
