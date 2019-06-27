# frozen_string_literal: true

class AddUseEnvRepoToProject < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :use_env_repo, :boolean, default: false, null: false
  end
end
