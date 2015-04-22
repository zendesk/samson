class CreateJenkinsJobs < ActiveRecord::Migration
  def change
    create_table :jenkins_jobs do |t|
      t.integer :jenkins_job_id, index: true, null: false
      t.string :name, null: false
      t.string :status
      t.string :error
      t.belongs_to :deploy, index: true, null: false

      t.timestamps null: false
    end
  end
end
