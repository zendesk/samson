class AddCsvExport < ActiveRecord::Migration
  def change
    create_table :csv_exports do |t|
      t.integer :user_id,    null: false
      t.timestamps           null: false
      t.timestamp :deleted_at
      t.string :content,        null: false
      t.string :status
      t.string :filename
    end
  end
end
