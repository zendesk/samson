require 'octokit'

class Changeset
  attr_reader :comparison, :repo, :previous_commit, :commit

  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(comparison, repo, previous_commit, commit)
    @comparison, @repo = comparison, repo
    @previous_commit, @commit = previous_commit, commit
  end

  def self.find(repo, previous_commit, commit)
    # If there's no previous commit, there's no basis no perform a comparison
    # on. Just show an empty changeset then.
    previous_commit ||= commit

    github = Octokit::Client.new(access_token: token)
    comparison = github.compare(repo, previous_commit, commit)

    new(comparison, repo, previous_commit, commit)
  rescue Octokit::NotFound
    new(NullComparison, repo, previous_commit, commit)
  end

  def github_url
    "https://github.com/#{repo}/compare/#{commit_range}"
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def commits
    @commits ||= comparison.commits.map {|data| Commit.new(repo, data) }
  end

  def files
    comparison.files
  end

  def pull_requests
    @pull_requests ||= find_pull_requests
  end

  def authors
    commits.map(&:author_name).uniq
  end

  private

  def find_pull_requests
    numbers = commits.map(&:pull_request_number).compact
    numbers.map {|num| PullRequest.find(repo, num) }
  end

  class NullComparison
    def self.commits
      []
    end

    def self.files
      []
    end
  end
end
