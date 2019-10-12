# frozen_string_literal: true
require 'uri'

# unknown users are considered the same since we do not have any identifying information in the user data
# and we don't want to show 10 'unknown' users on the release show page
class Changeset
  class GithubUser
    def initialize(data)
      @data = data
    end

    def avatar_url(size = 20)
      url = @data.avatar_url
      if url
        uri = URI(@data.avatar_url)
        params = URI.decode_www_form(uri.query || [])

        # The `s` parameter controls the size of the avatar.
        params << ["s", size.to_s]

        uri.query = URI.encode_www_form(params)
        uri.to_s
      else
        'https://assets-cdn.github.com/images/gravatars/gravatar-user-420.png'
      end
    end

    def url
      "#{Rails.application.config.samson.github.web_url}/#{login}" if login
    end

    def login
      @data.login
    end

    def identifier
      "@#{login}" if login
    end

    def eql?(other)
      login == other.login
    end

    def hash
      login&.hash || 123456789
    end
  end
end
