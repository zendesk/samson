# frozen_string_literal: true
class RemoveCommandFromStage < ActiveRecord::Migration[4.2]
  def change
    remove_column :stages, :command
  end
end
