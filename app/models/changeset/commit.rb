# frozen_string_literal: true
class Changeset::Commit
  PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/
  PULL_REQUEST_SQUASH_MESSAGE = /\A.*\(#(\d+)\)$/

  attr_reader :github

  def initialize(repo, data, github=true)
    @repo = repo
    @data = data
    @github = github
  end

  def author_name
    return @data.commit.author.name if github
    @data.commit.author_name
  end

  def author_email
    return @data.commit.author.email if github
    @data.commit.author_email
  end

  def author
    @author ||= Changeset::GithubUser.new(@data.author) if @data.author
  end

  def summary
    summary = if github
                @data.commit.message.split("\n").first
              else
                @data.commit.title.split("\n").first
              end
    summary.truncate(80)
  end

  def sha
    return @data.sha if github
    @data.commit.id
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
    return "#{Rails.application.config.samson.github.web_url}/#{@repo}/commit/#{sha}" if github
    "#{Rails.application.config.samson.gitlab.web_url}/#{@repo}/commit/#{sha}"
  end
end
