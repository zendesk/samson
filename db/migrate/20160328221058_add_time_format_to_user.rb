# frozen_string_literal: true
class AddTimeFormatToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :time_format, :string, default: 'relative', null: false
  end
end
