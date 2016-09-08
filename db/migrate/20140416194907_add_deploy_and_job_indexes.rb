# frozen_string_literal: true
class AddDeployAndJobIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :deploys, :job_id
    add_index :jobs, :project_id
  end
end
