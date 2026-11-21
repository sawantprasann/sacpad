module Account
  class PasswordsController < ApplicationController
    before_action :authenticate_user!

    def edit
      redirect_to account_settings_path(anchor: "security")
    end

    def update
      if current_user.update_with_password(password_params)
        bypass_sign_in(current_user)
        redirect_to account_settings_path, notice: t("account.updated")
      else
        load_social
        render "account/settings/show", status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
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
