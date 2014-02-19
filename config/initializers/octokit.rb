require 'octokit'
require 'faraday-http-cache'

Octokit.middleware = Faraday::Builder.new do |builder|
  builder.use Faraday::HttpCache, store: Rails.cache, serializer: Marshal
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter

  builder.options[:open_timeout] = 2
end
