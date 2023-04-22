class Webhooks::MoviesController < Webhooks::BaseController
  # A controller for catching new movie webhooks
  #
  # To send a sample webhook locally:
  #
  #   curl -X POST http://localhost:3000/webhooks/movies
  #     -H 'Content-Type: application/json'
  #     -d '{"title":"Dungeons & Dragons: Honor Among Thieves"}'
  #
  # Pass ?fail_verification=1 to simulate a webhook verification failure

  def create
    # Save webhook to database
    record = InboundWebhook.create!(body: payload)

    # Queue database record for processing
    Webhooks::MoviesJob.perform_later(record)

    head :ok
  end

  private

  # Pass ?fail_verification=1 to simulate a webhook verification failure
  def verify_event
    head :bad_request if params[:fail_verification]
  end

  def payload
    @payload ||= request.body.read
  end
end
