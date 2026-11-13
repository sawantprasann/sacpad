class InvitationsController < ApplicationController
  layout "auth"

  def edit
    @user = invited_user
    redirect_to new_user_session_path, alert: t("invite.invalid") if @user.nil?
  end

  def update
    @user = invited_user
    if @user.nil?
      redirect_to new_user_session_path, alert: t("invite.invalid")
      return
    end

    if @user.accept_invitation!(invitation_params[:password], invitation_params[:password_confirmation])
      sign_in(:user, @user)
      redirect_to root_path, notice: t("invite.accepted")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def invited_user
    user = User.find_by_invitation_token(params[:token])
    return if user.nil? || !user.pending_invitation? || user.invitation_expired?

    user
  end

  def invitation_params
    params.fetch(:user, {}).permit(:password, :password_confirmation)
  end
end
