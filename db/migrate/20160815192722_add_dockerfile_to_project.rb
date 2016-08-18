# frozen_string_literal: true
class AddDockerfileToProject < ActiveRecord::Migration
  def change
    add_column :projects, :dockerfile, :string, default: 'Dockerfile', null: false
  end
end
