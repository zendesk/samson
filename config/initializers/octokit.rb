# frozen_string_literal: true
require 'octokit'
require 'faraday-http-cache'

# we don't want to forever pay the price of redirects, but make users fix them
# https://github.com/octokit/octokit.rb/issues/771
#
# to reproduce/remove: rename a repository and try to create a diff with the old name
# it should return a NullComparison and not a broken Changeset with nil commits
# tested via test/models/changeset_test.rb
class Octokit::RedirectAsError < Faraday::Response::Middleware
  private

  def on_complete(response)
    if [301, 302].include?(response[:status].to_i)
      raise Octokit::RepositoryUnavailable, response
    end
  end
end

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, shared_cache: false, store: Rails.cache, serializer: Marshal
  builder.response :logger, Rails.logger
  builder.use Octokit::Response::RaiseError
  builder.use Octokit::RedirectAsError
  builder.adapter Faraday.default_adapter
end

Octokit.connection_options[:request] = {open_timeout: 2}

token = ENV['GITHUB_TOKEN']

raise "No GitHub token available" if !Rails.env.test? && !ENV['PRECOMPILE'] && token.blank?

Octokit.api_endpoint = Rails.application.config.samson.github.api_url
Octokit.web_endpoint = Rails.application.config.samson.github.web_url

GITHUB = Octokit::Client.new(access_token: token)
