class AddStageNewRelicApplications < ActiveRecord::Migration
  def change
    create_table :new_relic_applications do |t|
      t.string :name
      t.belongs_to :stage
      t.index [:stage_id, :name], unique: true, length: { name: 191 }
    end
  end
end
