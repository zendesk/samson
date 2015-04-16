class CommitStatus
  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(repo, sha)
    @repo, @sha = repo, sha
  end

  def status
    combined_status.state
  rescue Octokit::NotFound
  end

  private

  def combined_status
    @combined_status ||= GITHUB.combined_status(@repo, @sha)
  end
end
