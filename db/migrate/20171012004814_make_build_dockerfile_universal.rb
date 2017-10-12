# frozen_string_literal: true
class MakeBuildDockerfileUniversal < ActiveRecord::Migration[5.1]
  def change
    change_column_null :builds, :dockerfile, true
    add_column :builds, :image_name, :string
    add_index :builds, [:git_sha, :image_name], unique: true, length: {git_sha: 80, image_name: 80}
  end
end
