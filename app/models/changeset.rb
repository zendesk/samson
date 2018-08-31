# frozen_string_literal: true
class Changeset
  attr_reader :repo, :previous_commit, :commit, :github
  BRANCH_TAGS = ["master", "develop"].freeze
  ATTRIBUTE_TABS = %w[files commits pull_requests risks jira_issues].freeze

  def initialize(repo, previous_commit, commit, github=true)
    # repo is stringy for github, and used in URLs.
    # TODO must be able to handle previous_commit/commit names with branch/sha@date syntax for
    #      changelog controller.
    @repo = repo
    @commit = commit
    @previous_commit = previous_commit || @commit
    @github = github
  end

  def vcs_url
    return github_url if github
    gitlab_url
  end

  def commit_range
    "#{previous_commit}...#{commit}"
  end

  def comparison
    @comparison ||= find_comparison
  end

  def commits
    @commits ||= comparison.commits.map { |data| Commit.new(repo, data, github) }
  end

  def files
    github ? comparison.files : Files.new(comparison.diffs, github)
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

  def github_url
    "#{Rails.application.config.samson.github.web_url}/#{repo}/compare/#{commit_range}"
  end

  def gitlab_url
    "#{Rails.application.config.samson.gitlab.web_url}/#{repo}/compare/#{commit_range}"
  end

  # Called by Changeset(instance).comparison
  #   https://developer.github.com/v3/repos/commits/#compare-two-commits
  # Returned object possibly consumed by:
  #   app/views/changeset/_files.html.erb
  #   app/models/deploy.rb
  #   app/models/release.rb
  #   app/controllers/changelogs_controller.rb
  # Returns an object that responds to:
  # commits
  #   responds to map (probably an Enumerable)
  #   used to build a Changeset::Commit object
  # files which responds to .any?, .each type: Enumerable
  #   objects in files object above responds to:
  #   status, previous_filename, filename, additions, deletions, patch
  # error
  # pull_request_number
  #   Used to build Changeset::PullRequest
  def find_comparison
    return(find_github_comparison) if github
    find_gitlab_comparison
  end

  def find_github_comparison
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

  def find_gitlab_comparison
    if empty?
      NullComparison.new(nil)
    else
      if BRANCH_TAGS.include?(commit)
        @commit = GITLAB.branch(project_id, CGI.escape(commit)).commit[:id]
      end

      Rails.cache.fetch(cache_key) do
        GITLAB.compare(project_id, previous_commit, commit)
      end
    end
  rescue => e
    NullComparison.new("Gitlab: #{e.message}")
  end

  def project_id
    # Use repo to determine project_id.  
    # TODO We could optimize this by putting the gitlab project_id on the actual Samson Project
    # model.  This would be useful for a large list of repos.  I don't believe this will affect
    # Gitlab hosted projects, as the returned list is constrained to a user, but "Employer"
    # accounts or self hosted installations could benefit from this.
    if @project_id.nil?
      projects = GITLAB.projects(per_page: 20)
      projects.auto_paginate do |project|
        if project.path_with_namespace == repo
          @project_id = project.id
          break
        end
      end
      @project_id ||= 0
    end

    @project_id
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
