module Samson
  module Gitlab
    ##
    # Creates a file comparison structure that matches what is expected in the UI for deployment comparison.  This
    # is likely the structure used by GitHub, as Samson was designed to work with it.
    class Changeset::File
      attr_reader :filename, :previous_filename, :status, :patch, :additions, :deletions
      def initialize(project, sha, gitlab_compare_diff)
        @filename = gitlab_compare_diff['new_path']
        @previous_filename = gitlab_compare_diff['old_path']
        @patch = gitlab_compare_diff['diff']
        @project = project
        @sha = sha
        @commit = nil
        set_status(gitlab_compare_diff)
      end

      def additions
        commit.stats['additions'] rescue 0
      end

      def deletions
        commit.stats['deletions'] rescue 0
      end

      private

      def set_status(diff)
        @status = 'renamed' if diff['renamed_file']
        @status = 'added' if diff['new_file']
        @status = 'removed' if diff['deleted_file']
        @status = 'changed' unless @status
      end

      def commit
        @commit ||= ::Gitlab.client.commit(@project, @sha)
      end
    end
  end
end
