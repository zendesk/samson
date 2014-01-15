class Changeset::Commit
  def initialize(repo, data)
    @repo, @data = repo, data
  end

  def author_name
    @data.commit.author.name
  end

  def author_avatar_url
    gravatar_id = @data.author.gravatar_id
    "http://www.gravatar.com/avatar/#{gravatar_id}?s=20"
  end

  def author_url
    "https://github.com/#{@data.author.login}"
  end

  def message
    @data.commit.message
  end

  def sha
    @data.sha
  end

  def url
    "https://github.com/#{@repo}/commit/#{sha}"
  end
end
