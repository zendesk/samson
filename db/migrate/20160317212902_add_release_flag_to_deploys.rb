class AddReleaseFlagToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :release, :boolean, default: true, null: false
    change_column_default :deploys, :release, false
  end
end
