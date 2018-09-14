# frozen_string_literal: true
module Samson
  module Gitlab
    class Changeset::Commit
      PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/
      PULL_REQUEST_SQUASH_MESSAGE = /\A.*\(#(\d+)\)$/

      def initialize(repo, data)
        @repo = repo
        @data = data
      end

      def author_name
        @data['author_name']
      end

      def author_email
        @data['author_email']
      end

      def author
        @author ||= Changeset::GitlabUser.new(author_email) if author_email
      end

      def summary
        summary = @data['title'].split("\n").first
        summary.truncate(80)
      end

      def sha
        @data['id']
      end

      def short_sha
        sha.slice(0, 7)
      end

      def pull_request_number
        if number = summary[PULL_REQUEST_MERGE_MESSAGE, 1] || summary[PULL_REQUEST_SQUASH_MESSAGE, 1]
          Integer(number)
        end
      end

      def url
        "#{Rails.application.config.samson.gitlab.web_url}/#{@repo}/commit/#{sha}"
      end

      def self.status(project_name, ref)
        ref_commit = ::Gitlab.client.commit(project_name, ref)
        gitlab_status = ::Gitlab.commit_status(project_name, ref_commit.id, {ref: ref})
        normalize_status(gitlab_status)
      rescue StandardError => e  # Gitlab errors are all based on Standard Error
        {
            state: "failure",
            statuses: [{"state": "Reference", description: "'#{ref}' does not exist for #{project_name}"}]
        }
      end

      private

      ##
      # All of the upstream code expectes a structure that looks like GitHub's structure.  To minimize impact, this
      # method takes the GitLab structure and turns it not a GitHub like structure
      def self.normalize_status(gitlab_status)
        normalized_struct = {state: 'success', statuses: []}
        gitlab_status.each do |status|
          normalized_status = {}
          normalized_status[:url] = ''
          normalized_status[:avatar_url] = status.author.avatar_url
          normalized_status[:id] = status.author.id
          normalized_status[:node_id] = status.id
          normalized_status[:state] = status.author.state
          normalized_status[:description] = status.description
          normalized_status[:target_url] = status.target_url
          normalized_status[:context] = ''
          normalized_status[:created_at] = status.created_at
          normalized_status[:updated_at] = status.updated_at
          normalized_struct[:statuses] << normalized_status
        end
        normalized_struct
      end
    end
  end
end
