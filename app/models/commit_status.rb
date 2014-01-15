require 'octokit'

class CommitStatus
  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(repo, sha)
    @repo, @sha = repo, sha
  end

  def status
    if statuses.any?
      statuses.first.state
    end
  rescue Octokit::NotFound
  end

  private

  def github
    @github ||= Octokit::Client.new(access_token: token)
  end

  def statuses
    @statuses ||= github.statuses(@repo, @sha)
  end
end
