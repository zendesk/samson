# frozen_string_literal: true
class RemoveEnvRepo < ActiveRecord::Migration[6.0]
  def change
    remove_column :projects, :use_env_repo
  end
end
