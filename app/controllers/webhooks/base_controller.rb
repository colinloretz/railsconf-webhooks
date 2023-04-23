class Webhooks::BaseController < ApplicationController
  # Disable CSRF checking on webhooks because they do not originate from the browser
  skip_before_action :verify_authenticity_token

  def create
    head :ok
  end
end
