# frozen_string_literal: true
class Changeset
  attr_reader :project, :repo, :previous_commit, :commit
  BRANCH_TAGS = ["master", "develop"].freeze
  ATTRIBUTE_TABS = %w[files commits pull_requests risks jira_issues].freeze

  def initialize(project, previous_commit, commit)
    @project = project
    @repo = project.repository_path
    @commit = commit
    @previous_commit = previous_commit || @commit
  end

  def commit_range_url
    "#{project.repository_homepage}/compare/#{commit_range}"
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def comparison
    @comparison ||= find_comparison
  end

  def commits
    @commits ||= comparison.commits.map { |data| Commit.new(project, data) }
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
    commits.map(&:author).compact.uniq
  end

  def author_names
    commits.map(&:author_name).compact.uniq
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
        @commit =
          if project.gitlab?
            Gitlab.branch(repo, commit).commit.id
          else
            GITHUB.branch(repo, CGI.escape(commit)).commit[:sha]
          end
      end

      Rails.cache.fetch(cache_key) do
        if project.gitlab?
          Presenters::GitlabChangeset.new(Gitlab.compare(repo, previous_commit, commit)).build
        else
          GITHUB.compare(repo, previous_commit, commit)
        end
      end
    end
  rescue Octokit::Error, Faraday::ConnectionFailed => e
    NullComparison.new("GitHub: #{e.message.sub("Octokit::", "").underscore.humanize}")
  end

  def find_pull_requests
    numbers = commits.map(&:pull_request_number).compact
    numbers.map { |num| PullRequest.find(repo, num) }.
      compact.
      concat(find_pull_requests_for_branch)
  end

  def cache_key
    [self.class, repo, previous_commit, commit].join('-')
  end

  def find_pull_requests_for_branch
    return [] if not_pr_branch?
    org = repo.split("/", 2).first
    GITHUB.pull_requests(repo, head: "#{org}:#{commit}").map { |github_pr| PullRequest.find(repo, github_pr.number) }
  rescue Octokit::Error, Faraday::ConnectionFailed => e
    Rails.logger.warn "Failed fetching pull requests for branch #{commit}:\n#{e}"
    []
  end

  def not_pr_branch?
    commit =~ Build::SHA1_REGEX || commit =~ Release::VERSION_REGEX
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
