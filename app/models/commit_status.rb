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

  def statuses
    @statuses ||= GITHUB.statuses(@repo, @sha)
  end
end
