class HomeController < ApplicationController
  # The Organization Dashboard (FR50/FR51). Public landing when signed out; widget-composed
  # dashboard when signed in, each widget gated by the viewer's role permissions.
  def index
    @widgets = helpers.dashboard_widgets_for(current_user)
  end
end
