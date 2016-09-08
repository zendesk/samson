# frozen_string_literal: true
class AddPermalinkToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :permalink, :string
    add_index :stages, :permalink, unique: true, length: 191

    Stage.reset_column_information

    Stage.with_deleted do
      Stage.find_each do |stage|
        stage.send(:generate_permalink)
        stage.update_column(:permalink, stage.permalink)
      end
    end

    change_column :stages, :permalink, :string, null: false
  end
end
