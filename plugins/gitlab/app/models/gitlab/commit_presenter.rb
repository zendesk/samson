# frozen_string_literal: true
module Gitlab
  class CommitPresenter
    attr_reader :commit

    def initialize(commit)
      @commit = commit
    end

    def build
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
