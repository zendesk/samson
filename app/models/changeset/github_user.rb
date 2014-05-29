class Changeset::GithubUser
  def initialize(data)
    @data = data
  end

  def avatar_url
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
