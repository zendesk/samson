class CreateGuides < ActiveRecord::Migration
  def change
    create_table :guides do |t|
      t.integer :project_id
      t.text    :body
      t.timestamps
    end
    add_index :guides, :project_id
  end
end
