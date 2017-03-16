# frozen_string_literal: true
class Changeset::Commit
  PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/

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
    Integer(Regexp.last_match(1)) if summary =~ PULL_REQUEST_MERGE_MESSAGE
  end

  def url
    "#{Rails.application.config.samson.github.web_url}/#{@repo}/commit/#{sha}"
  end
end
