class AddNumberToBuilds < ActiveRecord::Migration
  def change
    change_table :builds do |t|
      t.integer :number, after: :project_id
    end
  end
end
