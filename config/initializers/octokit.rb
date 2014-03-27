require 'octokit'
require 'faraday-http-cache'

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

Octokit.connection_options[:request] = { open_timeout: 2 }
