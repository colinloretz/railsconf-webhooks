class Webhooks::BaseController < ActionController::API
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
