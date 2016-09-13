# frozen_string_literal: true
class AddOrderToStage < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :order, :integer
  end
end
