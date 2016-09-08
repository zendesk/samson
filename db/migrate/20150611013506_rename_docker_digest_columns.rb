# frozen_string_literal: true
class RenameDockerDigestColumns < ActiveRecord::Migration[4.2]
  def change
    change_table :builds do |t|
      t.remove_index column: :docker_sha
      t.rename :docker_sha, :docker_image_id
      t.rename :docker_image_url, :docker_repo_digest
    end
  end
end
