class AddSamsonSettings < ActiveRecord::Migration[5.0]
  def change
    create_table :settings do |t|
      t.string :name, :value, null: false
      t.string :comment
      t.timestamps null: false
      t.index :name, unique: true, length: {name: 192}
    end
  end
end
