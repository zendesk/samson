# frozen_string_literal: true
class AddNextStageToStages < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.string :next_stage_ids
    end
  end
end
