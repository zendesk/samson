# frozen_string_literal: true
module SamsonGitlab
  module Presenters
    class Changeset

      attr_reader :data

      def initialize(data)
        @data = data
      end

      def comparison
        OpenStruct.new(
          files: files,
          commits: commits
        )
      end

      private

      def files
        data.diffs.map do |file|
          patch = GitDiffParser::Patch.new(file['diff'])

          OpenStruct.new(
            filename: file['new_path'],
            status: status(file),
            patch: patch.body,
            additions: patch.changed_lines.size,
            deletions: patch.removed_lines.size
          )
        end
      end

      def status(file)
        if file['new_file']
          'added'
        elsif file['deleted_file']
          'removed'
        else
          'modified'
        end
      end

      def commits
        data.commits.map do |commit|
          OpenStruct.new(
            sha: commit['id'],
            commit: OpenStruct.new(
              author: OpenStruct.new(
                name: commit['author_name'],
                email: commit['author_email']
              ),
              message: commit['message']
            )
          )
        end
      end

    end
  end
end
