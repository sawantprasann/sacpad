class HomeController < ApplicationController
  before_action :authenticate_user!

  # The Organization Dashboard (FR50/FR51) — widget-composed, each widget gated by the viewer's
  # role permissions. Unauthenticated visitors are redirected to the (shell-less) sign-in page.
  def index
    @widgets = helpers.dashboard_widgets_for(current_user)
    load_constituency_election
  end

  private

  def load_constituency_election
    @constituency_election = ConstituencyElection.for_organization(current_user.organization).first
  end
end
