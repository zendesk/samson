require 'octokit'
require 'faraday-http-cache'

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, shared_cache: false, store: Rails.cache, serializer: Marshal
  builder.response :logger, Rails.logger
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

Octokit.connection_options[:request] = { open_timeout: 2 }

token = ENV['GITHUB_TOKEN']

unless Rails.env.test? || ENV['PRECOMPILE']
  raise "No GitHub token available" if token.blank?
end

Octokit.api_endpoint = "https://#{Rails.application.config.samson.github.api_url}"
Octokit.web_endpoint = "https://#{Rails.application.config.samson.github.web_url}"

GITHUB = Octokit::Client.new(access_token: token)
