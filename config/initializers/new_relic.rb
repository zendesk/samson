require 'new_relic_api'
require 'new_relic/agent/method_tracer'

NewRelicApi.port = 443
NewRelicApi.api_key = ENV['NEWRELIC_API_KEY']
ActiveResource::Base.logger = Rails.logger
