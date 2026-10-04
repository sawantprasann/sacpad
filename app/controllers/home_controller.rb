class HomeController < ApplicationController
  before_action :authenticate_user!

  # The Organization Dashboard (FR50/FR51) — widget-composed, each widget gated by the viewer's
  # role permissions. Unauthenticated visitors are redirected to the (shell-less) sign-in page.
  def index
    @widgets = helpers.dashboard_widgets_for(current_user)
  end

  # TailAdmin component showcase (Story 0.1a) — the sample page demonstrating the ui/ library.
  def style_guide
  end
end
