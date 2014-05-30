class AddDeployAndJobIndexes < ActiveRecord::Migration
  def change
    add_index :deploys, :job_id
    add_index :jobs, :project_id
  end
end
