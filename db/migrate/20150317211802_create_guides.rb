class CreateGuides < ActiveRecord::Migration
  def change
    create_table :guides do |t|
      t.integer :project_id
      t.text    :body
      t.timestamps
    end
  end
end
