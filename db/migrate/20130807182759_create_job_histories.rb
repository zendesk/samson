class CreateJobHistories < ActiveRecord::Migration
  def change
    create_table :job_histories do |t|
      t.text :log, :default => "", :null => false

      t.string :environment
      t.string :sha
      t.string :state
      t.string :channel

      t.belongs_to :project
      t.belongs_to :user

      t.timestamps
    end
  end
end
