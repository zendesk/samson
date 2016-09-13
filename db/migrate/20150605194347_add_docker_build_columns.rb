# frozen_string_literal: true
class AddDockerBuildColumns < ActiveRecord::Migration[4.2]
  def change
    change_table :builds do |t|
      t.string :docker_image_url, after: :docker_ref
      t.integer :docker_build_job_id, after: :docker_image_url
      t.string :label, after: :docker_build_job_id
      t.string :description, limit: 1024, after: :label
      t.integer :created_by, after: :description

      t.index :created_by
    end
  end
end
