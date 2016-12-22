# frozen_string_literal: true

class AddReleaseSources < ActiveRecord::Migration[5.0]
  def change
    add_column :projects, :release_source, :string, null: false, default: "any"
  end
end
