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

  # Verifies the event came from Stripe
  def verify_event
    signature = request.headers['Stripe-Signature']
    secret = Rails.application.credentials.dig(:stripe, :webhook_signing_secret)

    ::Stripe::Webhook::Signature.verify_header(
      payload,
      signature,
      secret.to_s,
      tolerance: Stripe::Webhook::DEFAULT_TOLERANCE,
    )
  rescue ::Stripe::SignatureVerificationError
    head :bad_request
  end

  def payload
    @payload ||= request.body.read
  end
end
