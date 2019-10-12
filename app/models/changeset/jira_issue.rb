# frozen_string_literal: true
class Changeset
  class JiraIssue
    attr_reader :url

    def initialize(url)
      @url = url
    end

    def reference
      @url.split("/").last
    end

    def ==(other)
      url == other.url
    end
  end
end
