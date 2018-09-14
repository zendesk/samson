# frozen_string_literal: true
require 'uri'

# unknown users are considered the same since we do not have any identifying information in the user data
# and we don't want to show 10 'unknown' users on the release show page
module Samson
  module Gitlab
    class Changeset::GitlabUser
      def initialize(user_email)
        begin
          users = ::Gitlab.client.users(search: user_email)
          @data = users.first || empty_user
        rescue StandardError => e
          @data = empty_user
        end
      end

      def avatar_url(size = 20)
        if @data.avatar_url
          uri = URI(@data.avatar_url)
          params = URI.decode_www_form(uri.query || '')

          # The `s` parameter controls the size of the avatar.
          params << ["s", size.to_s]

          uri.query = URI.encode_www_form(params)
          uri.to_s
        else
          'https://gitlab.com/assets/no_avatar-849f9c04a3a0d0cea2424ae97b27447dc64a7dbfae83c036c45b403392f0e8ba.png'
        end
      end

      def url
        @data.web_url if login
      end

      def login
        @data.web_url.split('/').last
      end

      def identifier
        "@#{login}" if login
      end

      def eql?(other)
        login == other.login
      end

      # Gitlab doesn't return a hash with a user
      def hash
        login&.hash || 123456789
      end

      private

      def empty_user
        OpenStruct.new({web_url: '', avatar_url: nil})
      end
    end
  end
end
