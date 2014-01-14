class AddDeletionTimeToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.timestamp :deleted_at
    end
  end
end
