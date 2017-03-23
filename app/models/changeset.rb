# frozen_string_literal: true
class Changeset
  attr_reader :repo, :previous_commit, :commit
  BRANCH_TAGS = ["master", "develop"].freeze

  def initialize(repo, previous_commit, commit)
    @repo = repo
    @commit = commit
    @previous_commit = previous_commit || @commit
  end

  def github_url
    "#{Rails.application.config.samson.github.web_url}/#{repo}/compare/#{commit_range}"
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def comparison
    @comparison ||= find_comparison
  end

  def commits
    @commits ||= comparison.commits.map { |data| Commit.new(repo, data) }
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
    comparison.error
  end

  private

  def find_comparison
    if empty?
      NullComparison.new(nil)
    else
      # for branches that frequently change we make sure to always get the correct cache,
      # others might get an outdated changeset if they are reviewed with different shas
      if BRANCH_TAGS.include?(commit)
        @commit = GITHUB.branch(repo, CGI.escape(commit)).commit[:sha]
      end

      Rails.cache.fetch(cache_key) do
        GITHUB.compare(repo, previous_commit, commit)
      end
    end
  rescue Octokit::Error, Faraday::ConnectionFailed => e
    NullComparison.new("GitHub: #{e.message.sub("Octokit::", "").underscore.humanize}")
  end

  def find_pull_requests
    numbers = commits.map(&:pull_request_number).compact
    numbers.map { |num| PullRequest.find(repo, num) }.compact
  end

  def cache_key
    [self.class, repo, previous_commit, commit].join('-')
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
  end
end
