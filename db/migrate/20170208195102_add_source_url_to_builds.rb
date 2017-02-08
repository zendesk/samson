# frozen_string_literal: true
class AddSourceUrlToBuilds < ActiveRecord::Migration[5.0]
  def change
    add_column :builds, :source_url, :string
  end
end
