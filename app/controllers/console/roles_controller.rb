module Console
  # Role & permission catalog editor (§3.3, Story 0.8) — the ONLY place roles are defined.
  class RolesController < BaseController
    before_action :set_role, only: %i[edit update destroy]

    def index
      @roles = Role.order(:id)
    end

    def new
      @role = Role.new
      build_missing_permissions(@role)
    end

    def create
      @role = Role.new(role_params)
      if @role.save
        redirect_to console_roles_path, notice: "Role created."
      else
        build_missing_permissions(@role)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      build_missing_permissions(@role)
    end

    def update
      if @role.update(role_params)
        redirect_to console_roles_path, notice: "Role updated."
      else
        build_missing_permissions(@role)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @role.is_system?
        redirect_to console_roles_path, alert: "System roles can't be deleted."
      elsif @role.destroy
        redirect_to console_roles_path, notice: "Role deleted."
      else
        redirect_to console_roles_path, alert: "Can't delete — role is still assigned."
      end
    end

    private

    def set_role
      @role = Role.find(params[:id])
    end

    # Ensure every module has a permission row to render in the matrix.
    def build_missing_permissions(role)
      existing = role.role_permissions.map(&:module_name)
      (Role::MODULES - existing).each do |m|
        role.role_permissions.build(module_name: m, access_level: "none")
      end
    end

    def role_params
      params.require(:role).permit(
        :name, :slug, :can_create_users,
        role_permissions_attributes: %i[id module_name access_level]
      )
    end
  end
end
