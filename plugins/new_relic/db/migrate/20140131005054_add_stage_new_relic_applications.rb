# frozen_string_literal: true
class AddStageNewRelicApplications < ActiveRecord::Migration[4.2]
  def change
    create_table :new_relic_applications do |t|
      t.string :name
      t.belongs_to :stage
      t.index [:stage_id, :name], unique: true, length: {name: 191}
    end
  end
end
