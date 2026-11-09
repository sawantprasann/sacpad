class DataDeletionsController < ApplicationController
  def show
    @request = SocialMedia::MetaDeletionRequest.find_by!(confirmation_code: params[:code])
  end
end
