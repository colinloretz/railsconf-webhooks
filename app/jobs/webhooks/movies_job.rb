class Webhooks::MoviesJob < ApplicationJob
  queue_as :default

  def perform(inbound_webhook)
    webhook_payload = JSON.parse(inbound_webhook.body, symbolize_names: true)
    # do whatever you'd like here with your webhook payload
    # call another service, update a record, etc.

    inbound_webhook.update!(status: :processed)
  end
end
