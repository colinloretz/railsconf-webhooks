Rails.application.routes.draw do
  namespace :webhooks do
    # /webhooks/movies routed to our Webhooks::MoviesController
    resource :movies, controller: :movies, only: [:create]

    # /webhooks/stripe routed to our Webhooks::StripeController
    resource :stripe, controller: :stripe, only: [:create]
  end

  # root "articles#index"
end
