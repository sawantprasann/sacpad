# Base Pundit policy. Tenant (organization) scoping is enforced at the model layer by
# acts_as_tenant; this base is where module-permission + hierarchy-subtree scoping are
# layered in by Stories 0.8/0.9. For now the Scope defers to acts_as_tenant's org filter.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?    = false
  def show?     = false
  def create?   = false
  def new?      = create?
  def update?   = false
  def edit?     = update?
  def destroy?  = false

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # acts_as_tenant already restricts to the current organization at the model layer.
    # Stories 0.8/0.9 narrow this further by module permission and hierarchy subtree.
    def resolve = scope.all

    private

    attr_reader :user, :scope
  end
end
