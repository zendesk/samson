# frozen_string_literal: true
class RenameBuildLabel < ActiveRecord::Migration[5.1]
  def change
    rename_column :builds, :label, :name
  end
end
