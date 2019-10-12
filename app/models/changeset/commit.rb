# frozen_string_literal: true
class Changeset
  class Commit
    PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/.freeze
    PULL_REQUEST_SQUASH_MESSAGE = /\A.*\(#(\d+)\)$/.freeze

    attr_reader :project

    def initialize(project, data)
      @project = project
      @repo = project.repository_path
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

    # @return [Integer, NilClass]
    def pull_request_number
      if number = summary[PULL_REQUEST_MERGE_MESSAGE, 1] || summary[PULL_REQUEST_SQUASH_MESSAGE, 1]
        Integer(number)
      end
    end

    def url
      "#{project.repository_homepage}/commit/#{sha}"
    end
  end
end
