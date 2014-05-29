class Changeset::GithubUser
  def initialize(data)
    @data = data
  end

  def avatar_url
    if Rails.application.config.samson.github.use_identicons
      identicon_url
    else
      gravatar_url
    end
  end

  def gravatar_url
    "https://www.gravatar.com/avatar/#{@data.gravatar_id}?s=20"
  end

  def identicon_url
    "https://#{Rails.application.config.samson.github.web_url}/identicons/#{login}.png"
  end

  def url
    "https://github.com/#{login}"
  end

  def login
    @data.login
  end

  def identifier
    "@#{login}"
  end

  def eql?(other)
    login == other.login
  end

  def hash
    login.hash
  end
end
