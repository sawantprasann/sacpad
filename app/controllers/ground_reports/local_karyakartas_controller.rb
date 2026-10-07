module GroundReports
  class LocalKaryakartasController < ApplicationController
    include LoadsVillage

    def create
      contact = @village.local_karyakartas.new(contact_params)
      contact.organization = current_user.organization
      authorize contact
      if contact.save
        redirect_to ground_reports_village_path(@village), notice: "Karyakarta added."
      else
        redirect_to ground_reports_village_path(@village), alert: contact.errors.full_messages.to_sentence
      end
    end

    private

    def contact_params
      params.require(:village_local_karyakarta).permit(:name, :phone, :notes)
    end
  end
end
