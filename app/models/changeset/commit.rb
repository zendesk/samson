class Changeset::Commit
  PULL_REQUEST_MERGE_MESSAGE = /\AMerge pull request #(\d+)/

  def initialize(repo, data)
    @repo, @data = repo, data
  end

  def author_name
    @data.commit.author.name
  end

  def author_avatar_url
    author = @data.author 

    if author.present?
      gravatar_id = author.gravatar_id
      "http://www.gravatar.com/avatar/#{gravatar_id}?s=20"
    end
  end

  def author_url
    "https://github.com/#{@data.author.login}"
  end

  def summary
    summary = @data.commit.message.split("\n").first
    summary.truncate(80)
  end

  def sha
    @data.sha
  end

  def short_sha
    @data.sha[0...7]
  end

  def pull_request_number
    if summary =~ PULL_REQUEST_MERGE_MESSAGE
      Integer($1)
    end
  end

  def url
    "https://github.com/#{@repo}/commit/#{sha}"
  end
end
