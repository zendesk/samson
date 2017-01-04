# frozen_string_literal: true
class RenameDockerRefToTag < ActiveRecord::Migration[5.0]
  def change
    rename_column :builds, :docker_ref, :docker_tag
  end
end
