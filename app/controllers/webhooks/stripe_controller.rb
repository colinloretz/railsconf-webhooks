class Webhooks::StripeController < Webhooks::BaseController
  def create
    # Save webhook to database
    record = InboundWebhook.create!(body: payload)

    # Queue database record for processing
    Webhooks::StripeJob.perform_later(record)

    # Tell Stripe everything was successful
    head :ok
  end

  private

  def payload
    @payload ||= request.body.read
  end
end
