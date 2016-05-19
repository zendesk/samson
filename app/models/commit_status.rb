class CommitStatus
  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(repo, sha)
    @repo = repo
    @sha = sha
  end

  def status
    combined_status[:state]
  end

  def status_list
    (combined_status[:statuses] || []).map(&:to_h)
  end

  def combined_status
    @combined_status ||= load_status
  end

  private

  def load_status
    GITHUB.combined_status(@repo, @sha)
  rescue Octokit::NotFound
    {}
  end
end
