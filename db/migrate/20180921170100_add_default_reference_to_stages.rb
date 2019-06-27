# frozen_string_literal: true

class AddDefaultReferenceToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :default_reference, :string
  end
end
