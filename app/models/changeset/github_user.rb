# frozen_string_literal: true
require 'uri'

class Changeset::GithubUser
  def initialize(data)
    @data = data
  end

  def avatar_url(size = 20)
    uri = URI(@data.avatar_url)
    params = URI.decode_www_form(uri.query || [])

    # The `s` parameter controls the size of the avatar.
    params << ["s", size.to_s]

    uri.query = URI.encode_www_form(params)
    uri.to_s
  end

  def url
    "#{Rails.application.config.samson.github.web_url}/#{login}"
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
