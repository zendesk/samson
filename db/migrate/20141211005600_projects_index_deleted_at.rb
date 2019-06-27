# frozen_string_literal: true
class ProjectsIndexDeletedAt < ActiveRecord::Migration[4.2]
  def change
    add_index :projects, [:permalink, :deleted_at], length: {permalink: 191}
    add_index :projects, [:token, :deleted_at], length: {token: 191}

    remove_index :projects, column: :permalink
    remove_index :projects, column: :token
  end
end
