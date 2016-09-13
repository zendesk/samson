# frozen_string_literal: true
class AddReleaseFlagToDeploys < ActiveRecord::Migration[4.2]
  def change
    add_column :deploys, :release, :boolean, default: true, null: false
    change_column_default :deploys, :release, false
  end
end
