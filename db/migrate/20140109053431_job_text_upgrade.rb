# frozen_string_literal: true
class JobTextUpgrade < ActiveRecord::Migration[4.2]
  def change
    change_column :jobs, :output, :text, limit: 1.gigabyte / 4 - 1
  end
end
