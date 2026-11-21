module Account
  class SettingsController < ApplicationController
    before_action :authenticate_user!

    def show
      load_social
    end

    def update
      load_social
      if (message = photo_error)
        current_user.assign_attributes(settings_params.except(:photo))
        current_user.errors.add(:base, message)
        render :show, status: :unprocessable_entity
        return
      end

      if current_user.update(settings_params)
        redirect_to account_settings_path, notice: t("settings.saved")
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def settings_params
      permitted = params.require(:user).permit(:name, :email, :phone, :photo)
      permitted.delete(:photo) if permitted[:photo].blank?
      permitted
    end

    def photo_error
      file = params.dig(:user, :photo)
      return if file.blank?
      return t("settings.photo_too_large") if file.size > 5.megabytes
      return if acceptable_photo?(file)

      t("settings.photo_invalid")
    end

    def acceptable_photo?(file)
      type = file.content_type.to_s
      type = "image/jpeg" if type == "image/jpg"
      return true if type.in?(%w[image/jpeg image/png image/webp])
      return false if type.present? && type != "application/octet-stream"

      File.extname(file.original_filename.to_s).downcase.in?(%w[.jpg .jpeg .png .webp])
    end

    def load_social
      @social_enabled = current_user.role.can_access?("social_media")
      return unless @social_enabled

      @pages = policy_scope(SocialMedia::SocialPage).order(:name)
      @facebook_ready = MetaApi.configured?
      @can_connect = policy(SocialMedia::SocialPage).connect?
    end
  end
end
