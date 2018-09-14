# frozen_string_literal: true
module Samson
  module Github
    class Changeset::Commit
      PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/
      PULL_REQUEST_SQUASH_MESSAGE = /\A.*\(#(\d+)\)$/

      def initialize(repo, data)
        @repo = repo
        @data = data
      end

      def author_name
        @data.commit.author.name
      end

      def author_email
        @data.commit.author.email
      end

      def author
        @author ||= Changeset::GithubUser.new(@data.author) if @data.author
      end

      def summary
        summary = @data.commit.message.split("\n").first
        summary.truncate(80)
      end

      def sha
        @data.sha
      end

      def short_sha
        @data.sha.slice(0, 7)
      end

      def pull_request_number
        if number = summary[PULL_REQUEST_MERGE_MESSAGE, 1] || summary[PULL_REQUEST_SQUASH_MESSAGE, 1]
          Integer(number)
        end
      end

      def url
        "#{Rails.application.config.samson.github.web_url}/#{@repo}/commit/#{sha}"
      end

      def self.status(project_name, ref)
        escaped_ref = ref.gsub(/[^a-zA-Z\/\d_-]+/) { |v| CGI.escape(v) }
        GITHUB.combined_status(project_name, escaped_ref).to_h
      rescue Octokit::NotFound
        {
            state: "failure",
            statuses: [{"state": "Reference", description: "'#{ref}' does not exist for #{project_name}"}]
        }
      end

    end
  end
end
