# frozen_string_literal: true
class EnableMultipleDockerfiles < ActiveRecord::Migration[5.1]
  def up
    add_column :projects, :dockerfiles, :string

    add_column :builds, :dockerfile, :string, default: 'Dockerfile', null: false
    add_index :builds, [:git_sha, :dockerfile], unique: true, length: {git_sha: 80, dockerfile: 80}
    remove_index :builds, :git_sha
  end

  def down
    remove_column :projects, :dockerfiles

    add_index :builds, :git_sha, unique: true, length: {git_sha: 80}
    remove_index :builds, [:git_sha, :dockerfile]
    remove_column :builds, :dockerfile
  end
end
