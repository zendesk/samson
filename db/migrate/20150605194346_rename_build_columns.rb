class RenameBuildColumns < ActiveRecord::Migration
  def change
    change_table :builds do |t|
      t.rename :docker_sha, :docker_sha
      t.rename :docker_ref, :docker_ref
    end
  end
end
