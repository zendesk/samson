# frozen_string_literal: true
class MoveScopes < ActiveRecord::Migration[5.1]
  class OauthAccessToken < ActiveRecord::Base
  end

  def up
    each_scope { |s| s.sub(/\bdefault\b/, "api").sub(/\bweb-ui\b/, "default") }
  end

  def down
    each_scope { |t| t.sub(/\bdefault\b/, "web-ui").sub(/\bapi\b/, "default") }
  end

  def each_scope
    OauthAccessToken.find_each do |token|
      token.scopes = yield token.scopes
      token.save if token.scopes_changed?
    end
  end
end
