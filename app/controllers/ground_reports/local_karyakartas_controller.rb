module GroundReports
  class LocalKaryakartasController < ApplicationController
    include LoadsVillage

    before_action :set_contact, only: %i[edit update destroy]

    def create
      contact = @village.local_karyakartas.new(contact_params)
      contact.organization = current_user.organization
      authorize contact
      if contact.save
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.karyakarta_added")
      else
        redirect_to ground_reports_village_path(@village), alert: contact.errors.full_messages.to_sentence
      end
    end

    def edit; end

    def update
      if @contact.update(contact_params)
        redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.karyakarta_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @contact.discard_by(current_user)
      redirect_to ground_reports_village_path(@village), notice: t("ground_reports.notices.karyakarta_deleted")
    end

    private

    def set_contact
      @contact = @village.local_karyakartas.kept.find(params[:id])
      authorize @contact
    end

    def contact_params
      params.require(:village_local_karyakarta).permit(:name, :phone, :address, :notes)
    end
  end
end
