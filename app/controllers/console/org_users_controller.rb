module Console
  # Login accounts for one organization. The platform admin can set a new password
  # or email a reset link. Scoped to organizations this admin is allowed to see.
  class OrgUsersController < BaseController
    before_action :set_organization
    before_action :set_user

    def reset_password
      if @user.pending_invitation?
        redirect_to console_organization_path(@organization), alert: "#{@user.name} has not accepted the invite. Resend the invite instead of setting a password."
        return
      end

      if @user.update(password_params)
        @user.unlock_access! if @user.access_locked?
        record_activity("user.password_reset", record: @user, organization: @organization)
        redirect_to console_organization_path(@organization), notice: "Password updated for #{@user.name}."
      else
        redirect_to console_organization_path(@organization), alert: @user.errors.full_messages.to_sentence
      end
    end

    def send_reset
      if @user.pending_invitation?
        @user.resend_invitation!
        record_activity("user.invitation_resent", record: @user, organization: @organization)
        redirect_to console_organization_path(@organization), notice: "Invite resent to #{@user.email}."
      else
        @user.send_reset_password_instructions
        record_activity("user.password_reset_email", record: @user, organization: @organization)
        redirect_to console_organization_path(@organization), notice: "Password reset link sent to #{@user.email}."
      end
    end

    private

    def set_organization
      @organization = current_admin.assignable_organizations.find(params[:organization_id])
    end

    def set_user
      @user = @organization.users.find(params[:id])
    end

    def password_params
      params.require(:user).permit(:password, :password_confirmation)
    end
  end
end
