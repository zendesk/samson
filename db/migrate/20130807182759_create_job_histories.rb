class CreateJobHistories < ActiveRecord::Migration
  def change
    create_table :job_histories do |t|
      t.text :log
      t.integer :status
      t.belongs_to :project
      t.timestamps
    end
  end
end
