class CommitStatus
  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(repo, ref)
    @repo, @ref = repo, ref
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

  def valid_ref?
    GitRepository.valid_ref_format?(@ref)
  end

  private

  def load_status
    valid_ref? ? GITHUB.combined_status(@repo, @ref) : {}
  rescue Octokit::NotFound
    {}
  end
end
