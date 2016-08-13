# frozen_string_literal: true
class AddOrderToStage < ActiveRecord::Migration
  def change
    add_column :stages, :order, :integer
  end
end
