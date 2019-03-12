# frozen_string_literal: true
module Gitlab
  class ChangesetPresenter
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def build
      OpenStruct.new(
        files: data.diffs.map { |file| Gitlab::FilePresenter.new(file).build },
        commits: data.commits.map { |commit| Gitlab::CommitPresenter.new(commit).build }
      )
    end
  end
end
