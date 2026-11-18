class PrivacyController < ApplicationController
  # Google's review opens this page with no PolitoMatrix account.
  layout "auth"

  def show
    I18n.locale = :en
  end
end
