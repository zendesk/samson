# frozen_string_literal: true
class AddVisibilityToSecrets < ActiveRecord::Migration
  def change
    add_column :secrets, :visible, :boolean, default: false, null: false
  end
end
