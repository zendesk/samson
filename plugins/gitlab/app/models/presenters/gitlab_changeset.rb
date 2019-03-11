# frozen_string_literal: true
module Presenters
  class GitlabChangeset
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def build
      OpenStruct.new(
        files: data.diffs.map { |file| Presenters::GitlabFile.new(file).build },
        commits: data.commits.map { |commit| Presenters::GitlabCommit.new(commit).build }
      )
    end
  end
end
