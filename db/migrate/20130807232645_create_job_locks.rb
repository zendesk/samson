class CreateJobLocks < ActiveRecord::Migration
  def change
    create_table :job_locks do |t|
      t.string :environment

      t.belongs_to :job_history
      t.belongs_to :project

      t.timestamp :created_at
      t.timestamp :expires_at
    end
  end
end
