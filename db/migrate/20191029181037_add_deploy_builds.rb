# frozen_string_literal: true
class AddDeployBuilds < ActiveRecord::Migration[5.2]
  def change
    create_table :deploy_builds do |t|
      t.references :build, index: true, null: false
      t.references :deploy, index: true, null: false
      t.timestamps
    end
  end
end
