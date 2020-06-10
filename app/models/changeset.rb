# frozen_string_literal: true

class Changeset
  ATTRIBUTE_TABS = ["files", "commits", "pull_requests", "risks", "jira_issues"].freeze
  MAIN_BRANCHES = ["master", "develop", "staging", "production"].freeze

  delegate :files, :error, to: :comparison

  def initialize(project, previous_commit, reference)
    @project = project
    @repo = project.repository_path
    @reference = reference
    @previous_commit = previous_commit || @reference
  end

  def commit_range_url
    "#{@project.repository_homepage}/compare/#{commit_range}"
  end

  def commit_range
    "#{@previous_commit}...#{@reference}"
  end

  def comparison
    @comparison ||= find_comparison
  end

  def commits
    @commits ||= comparison.commits.map { |data| Commit.new(@project, data) }
  end

  def pull_requests
    @pull_requests ||= begin
      numbers = (merged_pull_requests + open_pull_requests)
      PullRequest.name # call no-op method to load class before running in parallel
      Samson::Parallelizer.map(numbers) { |number| PullRequest.find(@repo, number) }.compact
    end
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

  # only reliable when comparing SHAs, but we only use it as "skip lookups" guard
  def empty?
    @previous_commit == @reference
  end

  private

  def find_comparison
    return NullComparison.new if empty?

    Rails.cache.fetch(compare_cache_key) do
      Samson::Hooks.fire(:repo_compare, @project, @previous_commit, @reference).compact.first ||
        NullComparison.new
    end
  rescue StandardError => e
    Changeset::NullComparison.new(error: "Repository error: #{e.message.split("::").last}")
  end

  # @return [Array<Integer>]
  def merged_pull_requests
    commits.map(&:pull_request_number).compact
  end

  # for branches that frequently change we make sure to always get the correct cache,
  # others might get an outdated changeset if they are reviewed with different shas
  # it then still does a http request, but it is much faster
  def compare_cache_key
    key =
      if static?
        @reference
      else
        @project.repo_commit_from_ref(@reference)
      end

    [self.class, @repo, @previous_commit, key].join('-')
  end

  # github only supports finding open PRs for branches (not commits or tags)
  # https://help.github.com/en/articles/searching-issues-and-pull-requests
  #
  # List response is not the same as the show response (missing commits/additions/etc), do not use PullRequest.new
  #
  # @return [Array<Integer>]
  def open_pull_requests
    return [] if static? || MAIN_BRANCHES.include?(@reference)
    org = @repo.split("/", 2).first
    GITHUB.pull_requests(@repo, head: "#{org}:#{@reference}").map(&:number)
  rescue Octokit::Error, Faraday::ConnectionFailed => e
    Rails.logger.warn "Failed fetching pull requests for branch #{@reference}:\n#{e}"
    []
  end

  def static?
    @reference =~ Build::SHA1_REGEX || @reference =~ Release::VERSION_REGEX
  end

  class NullComparison
    attr_reader :error

    def initialize(error: nil)
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
