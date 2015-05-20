class CreateBuildArtifact < ActiveRecord::Migration
  def change
    create_table :builds do |t|
      t.belongs_to :project,    null: false, index: true
      t.string :git_sha
      t.string :git_ref
      t.string :container_sha,  index: true
      t.string :container_ref
      t.timestamps

      t.index :git_sha, unique: true
    end
  end
end
