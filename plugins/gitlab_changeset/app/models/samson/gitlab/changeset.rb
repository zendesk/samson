# frozen_string_literal: true
require 'gitlab'

module Samson
  module Gitlab
    class Changeset
      attr_reader :repo, :previous_commit, :commit
      BRANCH_TAGS = ["master", "develop"].freeze
      ATTRIBUTE_TABS = %w[files commits pull_requests risks jira_issues].freeze

      def initialize(repo, previous_commit, commit)
        @repo = repo
        @commit = commit
        @previous_commit = previous_commit || @commit
      end

      def url
        "#{Rails.application.config.samson.gitlab.web_url}/#{repo}/compare/#{commit_range}"
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
        repo_files = []
        comparison.diffs.each do |diff|
          repo_files << Changeset::File.new(project_id, comparison.commit.id, diff)
        end
        repo_files
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
        author_names
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
          if BRANCH_TAGS.include?(commit)
            branch = gitlab_client.branch(project_id, CGI.escape(commit))
            @commit = branch.commit.id
          end
          Rails.cache.fetch(cache_key) do
            gitlab_client.compare(project_id, previous_commit, commit)
          end
        end
      rescue => e
        NullComparison.new(e.message)
      end

      def project_id
        if @project_id.nil?
          projects = gitlab_client.projects(per_page: 20)
          projects.auto_paginate do |project|
            if project.path_with_namespace == @repo
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
        numbers.map { |num| PullRequest.find(@repo, num) }.
          compact.
          concat(find_pull_requests_for_branch)
      end

      def cache_key
        [self.class, repo, previous_commit, commit].join('-')
      end

      def find_pull_requests_for_branch
        return [] if not_pr_branch?
        org = repo.split("/", 2).first
        gitlab_client.merge_requests(repo, head: "#{org}:#{commit}")
      rescue StandardError => e # Gitlab gem errors are all based on StandardError
        Rails.logger.warn "Failed fetching pull requests for branch #{commit}:\n#{e}"
        []
      end

      def not_pr_branch?
        commit =~ Build::SHA1_REGEX || commit =~ Release::VERSION_REGEX
      end

      def gitlab_client
        ::Gitlab.client
      end

      class NullComparison
        attr_reader :error

        def initialize(error)
          @error = error
        end

        def status
          @error
        end

        def commits
          []
        end

        def files
          []
        end
      end
    end
  end
end
