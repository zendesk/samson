# frozen_string_literal: true
class AddSamsonAppIndices < ActiveRecord::Migration[4.2]
  def change
    add_index :slack_identifiers, :user_id, unique: true
    add_index :slack_identifiers, :identifier, length: 12
    add_index :deploy_response_urls, :deploy_id, unique: true
  end
end
