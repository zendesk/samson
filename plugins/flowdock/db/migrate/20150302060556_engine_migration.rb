# frozen_string_literal: true
class EngineMigration < ActiveRecord::Migration[4.2]
  def change
    # does nothing but we will see it execute
    change_column_null :users, :name, false
  end
end
