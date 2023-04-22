class Webhooks::BaseController < ApplicationController
  # Disable CSRF checking on webhooks because they do not originate from the browser
  skip_before_action :verify_authenticity_token
  
  before_action :verify_event

  def create
    InboundWebhook.create(body: payload)
    head :ok
  end

  private

  def verify_event
    head :bad_request
  end

  def payload
    @payload ||= request.body.read
  end
end
