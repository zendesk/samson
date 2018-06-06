# frozen_string_literal: true
require 'gitlab'
# require 'faraday-http-cache'
require 'pry'

#
# TODO I imagine we must address this with gitlab gem as well... below is from octokit.rb
#
# we don't want to forever pay the price of redirects, but make users fix them
# https://github.com/octokit/octokit.rb/issues/771
#
# to reproduce/remove: rename a repository and try to create a diff with the old name
# it should return a NullComparison and not a broken Changeset with nil commits
# tested via test/models/changeset_test.rb
# class Octokit::RedirectAsError < Faraday::Response::Middleware
#   private
#
#   def on_complete(response)
#     if [301, 302].include?(response[:status].to_i)
#       raise Octokit::RepositoryUnavailable, response
#     end
#   end
# end

token = ENV['GITLAB_TOKEN']

unless Rails.env.test? || ENV['PRECOMPILE']
  raise "No Gitlab token available" if token.blank?
end

GITLAB = Gitlab.client(
  endpoint: Rails.application.config.samson.gitlab.api_url,
  private_token: token
)

#
# TODO Need to understand this
#
# Octokit.middleware = Faraday::RackBuilder.new do |builder|
#   builder.use Faraday::HttpCache, shared_cache: false, store: Rails.cache, serializer: Marshal
#   builder.response :logger, Rails.logger
#   builder.use Octokit::Response::RaiseError
#   builder.use Octokit::RedirectAsError
#   builder.adapter Faraday.default_adapter
# end

#
# TODO connection options for gitlab gem?
#
# Octokit.connection_options[:request] = { open_timeout: 2 }

# Log gitlab request timing so it is more obvious what we spent our time on
Gitlab::ObjectifiedHash.prepend(Module.new do
  def initialize(*)
    super
    # Rails.logger.info("GITHUB #{@env.method.upcase} (#{timing}s) #{@env.url}")
    #FIXME  ObjectifiedHash does not seem to have access to this...
    Rails.logger.info("GITLAB Not sure what is available for timing.")
  end
end)
