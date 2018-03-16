# frozen_string_literal: true

class AddRollbarReadTokenToProject < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :rollbar_read_token, :string
  end
end
