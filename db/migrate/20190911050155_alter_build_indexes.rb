# frozen_string_literal: true

class AlterBuildIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :builds, [:git_sha, :dockerfile]
    remove_index :builds, [:git_sha, :image_name]

    add_index :builds, [:git_sha, :dockerfile, :external_url],
      unique: true, length: {git_sha: 80, dockerfile: 80, external_url: 191}
    add_index :builds, [:git_sha, :image_name, :external_url],
      unique: true, length: {git_sha: 80, image_name: 80, external_url: 191}
  end
end
