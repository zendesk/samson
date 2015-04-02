class Changeset
  attr_reader :repo, :previous_commit, :commit

  def initialize(repo, previous_commit, commit)
    @repo, @commit = repo, commit
    @previous_commit = previous_commit || @commit
  end

  def github_url
    "https://#{Rails.application.config.samson.github.web_url}/#{repo}/compare/#{commit_range}"
  end

  def hotfix?
    Rails.cache.fetch("#{cache_key}-hotfix", expires_in: 1.year) do
      commits.any?(&:hotfix?)
    end
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def comparison
    @comparison ||= find_comparison
  end

  def commits
    @commits ||= comparison.commits.map {|data| Commit.new(repo, data) }
  end

  def last_commit_status
    if comparison.blank?
      StatusResult.null_result
    else
      ref = comparison.commits.last["sha"]
      state = Rails.cache.fetch(status_cache_key, expires_in: 1.minute)  do
        GITHUB.combined_status(repo, ref)[:state]
      end
      StatusResult.new(state, nil)
    end
  rescue Octokit::Error => e
    StatusResult.new(nil, "Unable to retrieve commit status. #{humanize_exception(e)}")
  end

  def files
    comparison.files
  end

  def pull_requests
    @pull_requests ||= find_pull_requests
  end

  def risks?
    risky_pull_requests.any?
  end

  def risky_pull_requests
    @risky_pull_requests ||= pull_requests.select(&:risky?)
  end

  def jira_issues
    @jira_issues ||= pull_requests.map(&:jira_issues).flatten
  end

  def authors
    commits.map(&:author).uniq
  end

  def author_names
    commits.map(&:author_name).uniq
  end

  def empty?
    @previous_commit == @commit
  end

  def error
    (comparison.error if comparison.respond_to?(:error)) ||
      last_commit_status.error
  end

  private

  def find_comparison
    if empty?
      NullComparison.new(nil)
    else
      Rails.cache.fetch(cache_key) do
        GITHUB.compare(repo, previous_commit, commit)
      end
    end
  rescue Octokit::Error => e
    NullComparison.new(humanize_exception(e))
  end

  def humanize_exception(e)
    "Github: #{e.message.sub("Octokit::", "").underscore.humanize}"
  end

  def find_pull_requests
    numbers = commits.map(&:pull_request_number).compact
    numbers.map {|num| PullRequest.find(repo, num) }.compact
  end

  def cache_key
    [self.class, repo, previous_commit, commit].join('-')
  end

  def status_cache_key
    [self.class, "status", repo, commit].join('-')
  end

  class NullComparison
    attr_reader :error

    def initialize(error)
      @error = error
    end

    def commits
      []
    end

    def files
      []
    end

    def blank?
      true
    end
  end
end
