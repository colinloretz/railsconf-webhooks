class Webhooks::MoviesController < Webhooks::BaseController
    # A controller for catching new movie webhooks
  #
  # To send a sample webhook locally:
  #
  #   curl -X POST http://localhost:3000/webhooks/movies
  #     -H 'Content-Type: application/json'
  #     -d '{"title":"Dungeons & Dragons: Honor Among Thieves"}'
  #  
  # If you'd like to override the base controller's behavior, you can do so here
  # def create
  #   head :ok
  # end
end
