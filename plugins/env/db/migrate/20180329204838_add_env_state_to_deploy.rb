# frozen_string_literal: true

class AddEnvStateToDeploy < ActiveRecord::Migration[5.1]
  def change
    add_column :deploys, :env_state, :text
  end
end
