# RailsConf 2023: Webhooks Workshop

### Catch Me If You Can: Learning to Process Webhooks in Your Rails App

This workshop will be taught on on Tuesday, April 25th at [RailsConf 2023](https://railsconf.org/) in Atlanta.

> In this workshop, you’ll learn how to catch and process webhooks like a pro. You’ll build a Rails app that’s both robust and low-latency so you keep up in real-time like a champ. Come ready to level up your skills and leave with the expertise you need to become a true webhook wizard!
>
> We will begin by exploring the fundamentals of webhooks: how they work, why they are useful, and how they differ from other approaches. We will then dive into the hard-won lessons learned for consuming and processing webhooks, including routing, handling payloads, and responding to events.
>
> Along the way, we will explore best practices like error handling, authentication, retries, idempotency, and scaling. You’ll walk away with a solid understanding for how to build a resilient and robust system to handle webhook notifications from a wide range of external services and APIs. Attendees will leave the workshop with a working webhook processor running on Rails!

## How To Use This Repository

There are many ways to support webhooks in your application. For the interest of this workshop, we will be covering a straightforward approach that uses common Rails patterns from end to end.

As you evolve your own webhook handling and develop your own style, you will find areas that might benefit from middleware and more intermediate/advanced methods.

### Branches

To allow you to follow along, we've set up each step as a branch so you can see the difference from each step. `main` contains the final project with all the PRs merged but you can checkout the `starter` branch to move to the starting point. We have included instructions below under Getting Started.

You can check out each subsequent step with the following branches:

- `git checkout step1-routes`
- `git checkout step2-webhook-model`
- `git checkout step3-background-job`
- `git checkout step4-verification`
- `git checkout step5-tests`

# Webhooks Tutorial

Star this repository so we know you have taken this workshop!

## Pull down the workshop repository

Pull down the repository and switch to the `starter` remote branch

```bash
# clone from Github
git clone git@github.com:colinloretz/railsconf-webhooks.git

# move into directory
cd railsconf-webhooks

# fetch all the upstream branches that include the steps of this workshop
git fetch --all

# checkout the starter branch
git checkout starter

# install dependencies
bundle install

# start server
rails server
```

You should now have a brand new Rails app up and running. You can verify by visiting [http://localhost:3000](http://localhost:3000)

## Step 1: Setting Up a Controller and Rails Routes

We'll start by creating a controller and an HTTP route to catch the webhook events.

### 1A) Creating a Base Controller

We'll start by creating a base controller that all of our webhook controllers will inherit from. This will allow us to add common functionality to all of our webhook controllers.

```bash
rails generate controller Webhooks::BaseController
```

```ruby
# app/controllers/webhooks/base_controller.rb

class Webhooks::BaseController < ApplicationController
  # Disable CSRF checking on webhooks because they do not originate from the browser
  skip_before_action :verify_authenticity_token

  def create
    head :ok
  end
end
```

For this workshop we are going to catch webhooks from two sources: a fake webhook provider `Movies` and `Stripe`. We'll create a controller for each of these webhook sources and inherit the `Webhook::BaseController`

### 1B) Creating the Movies Webhook Controller

This fake Movies controller also includes an example of how to send a webhook to your application. You can use this to test your webhook processor.

```bash
rails generate controller Webhooks::MoviesController
```

```ruby
# app/controllers/webhooks/movies_controller.rb

class Webhooks::MoviesController < ApplicationController
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
```

Let's create the Stripe webhook controller while we are here.

### 1C) Creating the Stripe Webhook Controller

```bash
rails generate controller Webhooks::StripeController
```

```ruby
# app/controllers/webhooks/stripe_controller.rb

class Webhooks::StripeController < Webhooks::BaseController
  # If you'd like to override the base controller's behavior, you can do so here
  # def create
  #   head :ok
  # end
end
```

### 1D) Adding Routes for the Webhook Controllers

Finally, we need to add routes for these webhook controllers.

We are going to set up routes that are namespaced to `/webhooks` and then have a route for each webhook controller. We will only allow the `create` action on these routes.

_As you add more webhook providers, you can also create a dynamic route that will catch all webhooks and route them to a single controller. This is a common pattern for webhook processors._

```ruby
# config/routes.rb

Rails.application.routes.draw do
  namespace :webhooks do
    # /webhooks/movies routed to our Webhooks::MoviesController
    resource :movies, controller: :movies, only: [:create]

    # /webhooks/stripe routed to our Webhooks::StripeController
    resource :stripe, controller: :stripe, only: [:create]
  end

  # your other routes here
end
```

### 1E) Testing our new routes

We can test our new routes by sending a request to our new webhook routes. We can use `curl` to send a request to our new webhook routes.

Let's boot up the server and send a request to our new webhook routes.

This should be successful and return a `200` status code.

```bash
curl -X POST 'http://localhost:3000/webhooks/movies' -H 'Content-Type: application/json' -d '{"title":"Dungeons & Dragons: Honor Among Thieves"}' -v
```

We can't easily test our Stripe webhooks without setting up a Stripe account and configuring it to send webhooks to our application. We'll include instructions for this in a later step.

Now that we have our routes set up, we can move on to creating a webhook model.

💡 You can checkout the branch `step1-routes` using `git checkout step1-routes` to get caught up to this step before continuing.

## Step 2: Creating a Webhook Model

This model will be responsible for storing the inbound webhook until a background job can process it.

The reason we want to do this is because we want our controller to respond as fast as possible for heavy traffic (like Black Friday for example) and we want to store the record in the database to safely store it for retries if the service is having trouble for any reason.

### 2A) Creating the Webhook Model

We can use the Rails generator to create our model and the associated helper files.

```bash
rails generate model InboundWebhook status:string body:text
```

We should now have a pretty empty model file and a migration file.

```ruby
# app/models/inbound_webhook.rb

class InboundWebhook < ApplicationRecord
end
```

```ruby
# db/migrate/20230401162628_create_inbound_webhooks.rb

class CreateInboundWebhooks < ActiveRecord::Migration[7.0]
  def change
    create_table :inbound_webhooks do |t|
      t.string :status, default: :pending
      t.text :body

      t.timestamps
    end
  end
end
```

We can run our migration to create the table in the database.

```bash
rails db:migrate
```

Now that we have a model and a backing table in the database, we can save our webhook to the database. Let's update our `Webhook::BaseController` or each of our webhook controllers to save the webhook to the database.

```ruby
# app/controllers/webhooks/base_controller.rb

class Webhooks::BaseController < ApplicationController
  # Disable CSRF checking on webhooks because they do not originate from the browser
  skip_before_action :verify_authenticity_token

  def create
    InboundWebhook.create(body: payload)
    head :ok
  end

  private

  def payload
    @payload ||= request.body
  end
end
```

Now if you test your Movies webhook route, you should see a new record in the database.

```bash
curl -X POST 'http://localhost:3000/webhooks/movies' -H 'Content-Type: application/json' -d '{"foo":"bar"}' -v
```

💡 You can checkout the branch `step2-webhook-model` using `git checkout step2-webhook-model` to get caught up to this step before continuing.

## Step 3: Creating a Background Worker

Now that we have a record in our database, we need to process it. We don't want to process it in the controller because that would slow down our response time. Instead, we want to process it in a background job.

### 3A) Creating the Background Job

Let's use another Rails generator to create a background job.

In thise case, we are going to use the `ActiveJob` framework that comes with Rails. This will allow us to easily switch between background job providers like Sidekiq, Resque, DelayedJob, etc.

Let's make a job for each of our webhook providers within a `Webhooks` namespace.

```bash
rails generate job Webhooks::MoviesJob
```

```ruby
# app/jobs/webhooks/movies_job.rb

class Webhooks::MoviesJob < ApplicationJob
  queue_as :default

  def perform(inbound_webhook)
    webhook_payload = JSON.parse(inbound_webhook.body, symbolize_names: true)
    # do whatever you'd like here with your webhook payload
    # call another service, update a record, etc.
  end
end
```

```bash
rails generate job Webhooks::StripeJob
```

```ruby
# app/jobs/webhooks/stripe_job.rb

class Webhooks::StripeJob < ApplicationJob
  queue_as :default

  def perform(inbound_webhook)
    json = JSON.parse(inbound_webhook.body, symbolize_names: true)
    event = Stripe::Event.construct_from(json)
    case event.type
    when 'customer.updated'
      # Find customer and save changes
    end
  end
end
```

💡 You can checkout the branch `step3-background-job` using `git checkout step3-background-job` to get caught up to this step before continuing.

## Step 4: Verifying Webhooks

Verifying webhooks is an important step to make sure that the event is a real event that you expect from the Webhook Provider.

In our controllers, we have created a `verify_event` method that is called as a before_action in our base controller.

For testing purposes with our Movie webhooks, we have added a `verify_event` method that is always true unless you pass in a `fail_verification` url parameter on the webhook endpoint.

```ruby
# app/controllers/webhooks/movies_controller.rb
# ... rest of controller

private

def verify_event
  head :bad_request if params[:fail_verification]
end
```

To verify Stripe webhooks in `Webhooks::StripeController`, Stripe provides a method in their ruby gem that uses a combination of a Webhook Signature, your Stripe signing secret and the JSON payload to verify the event.

```ruby
# app/controllers/webhooks/stripe_controller.rb
# ... rest of controller

private

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
```

When consuming webhooks from other sources, you would customize `verify_event` to match the signature verification method that the Webhook Provider has in their webhook documentation.

For webhooks that don't provide verification methods, you can optionally call to the source API to check that the event has happened or that data has been created/updated as the event suggests.

However, it is recommended that you do this in the background job that processes the webhook so you don't make unnecessary API calls while returning a status back to the Webhook Provider.

💡 You can checkout the branch `step4-verification` using `git checkout step4-verification` to get caught up to this step before continuing.

## Step 5: Writing tests for our Webhook Processor

`!todo`

💡 You can checkout the branch `step5-tests` using `git checkout step5-tests` to get caught up to this step before continuing.

## More Advanced Topics To Consider

### Retries

Usually retries are done on the Webhook Producer side of things. However, if you are receiving a lot of webhooks and you are having trouble processing them all, you may want to implement background job retries in your application. When doing this, you will also want to make sure you have an idempotency method in place to ensure that you don't process the same webhook event more than once.

### Idempotency & Deduplication

As a Webhook Consumer, you want to make sure that you don't process the same webhook event multiple times. This is especially important if you are doing something like updating a record in your database.

Most Webhook Providers offer a unique identifier or idempotency method for each webhook event. You can use this to ensure that you don't process the same webhook event more than once.

### Backfilling Missing Events

The beauty of webhooks is that it is an evented-architecture. However, they are not always 100% reliable and a provider may not be able to deliver a webhook event to your application.

If a webhook provider is unable to deliver a webhook to your application, most will retry a certain number of times over a given time period (usually with exponential backoff). However, if after that time, they still were not able to deliver the webhook payload OR had some sort of service outage, you might be missing important webhook events.

You can implement other API calls to the service that runs on an interval or when other events are received to check if any other events happened since the last event was received.

# Webhooks Best Practices & Tools

- [Webhooks.fyi: Best Practices for Webhook Consumers](https://webhooks.fyi/best-practices/webhook-consumers)
- [Stripe: Using incoming webhooks to get real-time updates](https://stripe.com/docs/webhooks)
- [Twilio: What is a Webhook?](https://www.twilio.com/docs/glossary/what-is-a-webhook)
- [Zapier: What are Webhooks?](https://zapier.com/blog/what-are-webhooks/)

**Popular Options for safe ingress into your application from the outside world**

- [ngrok](https://ngrok.com)
- [Cloudflare tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
