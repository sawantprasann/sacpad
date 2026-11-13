# Org-facing hierarchical user management (§3.2/§3.5). Creating and managing a user is gated
# by the acting user's role.can_create_users? (default org_admin only). A new user is parented
# to its creator. Later edits, deactivation, invites, and password resets stay inside that subtree.
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: %i[edit update deactivate reactivate resend_invitation send_password_reset]

  def index
    @users = policy_scope(User)
  end

  def new
    @user = User.new
    authorize @user
    load_roles
  end

  def create
    @user = current_user.organization.users.new(user_params)
    @user.parent = current_user
    authorize @user
    if @user.deliver_invitation!
      redirect_to users_path, notice: t("team.created", email: @user.email)
    else
      load_roles
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_roles
  end

  def update
    was_pending = @user.pending_invitation?
    if @user.update(user_params)
      if was_pending && @user.saved_change_to_email?
        @user.resend_invitation!
        redirect_to users_path, notice: t("team.updated_reinvited", email: @user.email)
      else
        redirect_to users_path, notice: t("team.updated", name: @user.name)
      end
    else
      load_roles
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @user.update!(active: false)
    redirect_to users_path, notice: t("team.deactivated", name: @user.name)
  end

  def reactivate
    @user.update!(active: true)
    redirect_to users_path, notice: t("team.reactivated", name: @user.name)
  end

  def resend_invitation
    if @user.resend_invitation!
      redirect_to users_path, notice: t("team.invite_resent", email: @user.email)
    else
      redirect_to users_path, alert: t("team.invite_resend_failed")
    end
  end

  def send_password_reset
    @user.send_reset_password_instructions
    redirect_to users_path, notice: t("team.reset_sent", email: @user.email)
  end

  private

  def set_user
    @user = policy_scope(User).find(params[:id])
    authorize @user
  end

  def user_params
    params.require(:user).permit(:name, :email, :phone, :role_id)
  end

  # Booth managers are added from a booth, which also assigns that booth.
  # Keep the current role available when editing someone who already has it.
  def load_roles
    scope = Role.where.not(slug: "booth_manager")
    scope = scope.or(Role.where(id: @user.role_id)) if @user.role_id.present?
    @roles = scope.order(:name)
  end
end
