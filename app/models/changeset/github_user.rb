class Changeset::GithubUser
  def initialize(data)
    @data = data
  end

  def avatar_url
    "https://www.gravatar.com/avatar/#{@data.gravatar_id}?s=20"
  end

  def url
    "https://github.com/#{login}"
  end

  def login
    @data.login
  end

  def eql?(other)
    login == other.login
  end

  def hash
    login.hash
  end
end
