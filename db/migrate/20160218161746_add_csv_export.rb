class AddCsvExport < ActiveRecord::Migration
  def change
    create_table :csv_exports do |t|
      t.integer :user_id,    null: false
      t.timestamps           null: false
      t.string :filters, default: "{}"
      t.string :status, default: "pending"
    end
  end
end
