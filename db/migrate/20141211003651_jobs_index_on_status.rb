class JobsIndexOnStatus < ActiveRecord::Migration
  def change
    add_index :jobs, :status
  end
end
