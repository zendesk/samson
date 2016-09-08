# frozen_string_literal: true
class AddNumberToBuilds < ActiveRecord::Migration[4.2]
  def change
    change_table :builds do |t|
      t.integer :number, after: :project_id
    end
  end
end
