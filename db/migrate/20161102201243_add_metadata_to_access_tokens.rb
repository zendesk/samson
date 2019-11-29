# frozen_string_literal: true
class AddMetadataToAccessTokens < ActiveRecord::Migration[5.0]
  def change
    add_column :oauth_access_tokens, :description, :string
    add_column :oauth_access_tokens, :last_used_at, :datetime
  end
end
