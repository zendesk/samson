class EngineMigration < ActiveRecord::Migration
  def change
    # does nothing but we will see it execute
    change_column_null :users, :name, false
  end
end
