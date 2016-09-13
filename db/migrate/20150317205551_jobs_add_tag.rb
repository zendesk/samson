# frozen_string_literal: true
class JobsAddTag < ActiveRecord::Migration[4.2]
  def change
    add_column :jobs, :tag, :string
  end
end
