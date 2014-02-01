require 'new_relic_api'

NewRelicApi.port = 443
NewRelicApi.api_key = ENV['NEWRELIC_API_KEY']
ActiveResource::Base.logger = Rails.logger
