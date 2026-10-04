# Org-facing hierarchical user management (§3.2/§3.5). Creating a user is gated by the acting
# user's role.can_create_users? (default org_admin only) and the new user is parented to its creator.
class UsersController < ApplicationController
  before_action :authenticate_user!

  def index
    @users = policy_scope(User)
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = current_user.organization.users.new(user_params)
    @user.parent = current_user
    authorize @user
    if @user.save
      redirect_to users_path, notice: "User created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :phone, :role_id, :password)
  end
end
