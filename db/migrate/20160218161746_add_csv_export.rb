class AddCsvExport < ActiveRecord::Migration
  def change
    create_table :csv_exports do |t|
      t.integer :user_id,    null: false
      t.timestamps           null: false
      t.string :filters,     null: false,  default: "{}"
      t.string :status,      null: false,  default: "pending"
    end
  end
end
