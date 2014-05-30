class CreateLocks < ActiveRecord::Migration
  def change
    create_table :locks do |t|
      t.belongs_to :stage
      t.belongs_to :user

      t.timestamps
      t.timestamp :deleted_at
    end
  end
end
