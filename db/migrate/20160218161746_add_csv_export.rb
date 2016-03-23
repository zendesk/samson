class AddCsvExport < ActiveRecord::Migration
  def change
    create_table :csv_exports do |t|
      t.integer :user_id,    null: false
      t.timestamps           null: false
      t.text :filters,       null: false
      t.string :status
    end
  end
end
