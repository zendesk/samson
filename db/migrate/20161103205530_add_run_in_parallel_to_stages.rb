# frozen_string_literal: true
class AddRunInParallelToStages < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :run_in_parallel, :boolean, default: false, null: false
  end
end
