# frozen_string_literal: true
class RemoveBuildExternalId < ActiveRecord::Migration[5.1]
  def change
    remove_column :builds, :external_id, :string
  end
end
