require 'octokit'

class Changeset
  attr_reader :previous_commit, :commit

  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(repo, previous_commit, commit)
    @repo, @previous_commit, @commit = repo, previous_commit, commit

    # If there's no previous commit, there's no basis no perform a comparison
    # on. Just show an empty changeset then.
    @previous_commit ||= @commit
  end

  def github_url
    "https://github.com/#{@repo}/compare/#{commit_range}"
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def commits
    comparison.commits.map {|data| Commit.new(@repo, data) }
  end

  def files
    comparison.files
  end

  def authors
    commits.map(&:author_name).uniq
  end

  private

  def comparison
    @comparison ||= get_comparison
  end

  def get_comparison
    github.compare(@repo, @previous_commit, @commit)
  rescue Octokit::NotFound
    NullComparison
  end

  def github
    @github ||= Octokit::Client.new(access_token: token)
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
