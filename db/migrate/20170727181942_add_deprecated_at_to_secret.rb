# frozen_string_literal: true
class AddDeprecatedAtToSecret < ActiveRecord::Migration[5.1]
  def change
    add_column :secrets, :deprecated_at, :timestamp
  end
end
