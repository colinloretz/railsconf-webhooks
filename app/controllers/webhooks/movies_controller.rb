class Webhooks::MoviesController < Webhooks::BaseController
    # A controller for catching new movie webhooks
  #
  # To send a sample webhook locally:
  #
  #   curl -X POST http://localhost:3000/webhooks/movies
  #     -H 'Content-Type: application/json'
  #     -d '{"title":"Dungeons & Dragons: Honor Among Thieves"}'
  #  
  def create
    # Save webhook to database
    record = InboundWebhook.create!(body: payload)

    # Queue database record for processing
    Webhooks::MoviesJob.perform_later(record)

    head :ok
  end

  private

  def payload
    @payload ||= request.body.read
  end
end
