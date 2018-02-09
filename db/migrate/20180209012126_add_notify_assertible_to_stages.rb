# frozen_string_literal: true

class AddNotifyAssertibleToStages < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :notify_assertible, :boolean, default: false, null: false
  end
end
