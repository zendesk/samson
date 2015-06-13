class RenameDockerDigestColumns < ActiveRecord::Migration
  def change
    change_table :builds do |t|
      t.remove_index column: :docker_sha
      t.rename :docker_sha, :docker_image_id
      t.rename :docker_image_url, :docker_repo_digest
    end
  end
end
