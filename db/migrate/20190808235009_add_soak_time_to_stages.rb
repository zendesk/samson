class AddSoakTimeToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :soak_time, :integer
  end
end
