# frozen_string_literal: true
class CreateDeployGroups < ActiveRecord::Migration
  def change
    create_table :environments do |t|
      t.string :name, null: false
      t.boolean :is_production, default: false, null: false
      t.timestamp :deleted_at

      t.timestamps null: false
    end

    create_table :deploy_groups do |t|
      t.string :name, null: false
      t.references :environment, index: true, null: false
      t.timestamp :deleted_at

      t.timestamps null: false
    end
    add_foreign_key :deploy_groups, :environments

    create_table :deploy_groups_stages, id: false do |t|
      t.belongs_to :deploy_group, index: true
      t.belongs_to :stage, index: true
    end
  end
end
