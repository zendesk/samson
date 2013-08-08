class CreateJobHistories < ActiveRecord::Migration
  def change
    create_table :job_histories do |t|
      t.text :log

      t.string :environment
      t.string :state

      t.belongs_to :project
      t.belongs_to :user

      t.timestamp :expires_at
      t.timestamps
    end
  end
end
