# frozen_string_literal: true
module Gitlab
  class FilePresenter
    ADDED = 'added'
    MODIFIED = 'modified'
    REMOVED = 'removed'

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def build
      patch = GitDiffParser::Patch.new(file['diff'])

      OpenStruct.new(
        filename: file['new_path'],
        status: status(file),
        patch: patch.body,
        additions: patch.changed_lines.size,
        deletions: patch.removed_lines.size
      )
    end

    private

    def status(file)
      if file['new_file']
        ADDED
      elsif file['deleted_file']
        REMOVED
      else
        MODIFIED
      end
    end
  end
end
