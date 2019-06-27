# frozen_string_literal: true

class BumpEnvStateSize < ActiveRecord::Migration[5.2]
  def change
    change_column :deploys, :env_state, :text, limit: 16777215
  end
end
