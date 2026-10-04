class HomeController < ApplicationController
  before_action :authenticate_user!, only: :style_guide

  # The Organization Dashboard (FR50/FR51). Public landing when signed out; widget-composed
  # dashboard when signed in, each widget gated by the viewer's role permissions.
  def index
    @widgets = helpers.dashboard_widgets_for(current_user)
  end

  # TailAdmin component showcase (Story 0.1a) — the sample page demonstrating the ui/ library.
  def style_guide
  end
end
