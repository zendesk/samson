# frozen_string_literal: true
class AddFullCheckoutToStages < ActiveRecord::Migration[5.2]
  def change
    add_column :stages, :full_checkout, :boolean, default: false, null: false
  end
end
