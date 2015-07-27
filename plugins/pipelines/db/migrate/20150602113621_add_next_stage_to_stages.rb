class AddNextStageToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :next_stage_ids
    end
  end
end
