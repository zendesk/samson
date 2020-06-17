# frozen_string_literal: true
class InstallAudited < ActiveRecord::Migration[5.1]
  def self.up
    create_table :audits, force: true do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.column :auditable_id, :integer, null: false
      t.column :auditable_type, :string, null: false
      t.column :associated_id, :integer
      t.column :associated_type, :string
      t.column :user_id, :integer
      t.column :user_type, :string
      t.column :username, :string
      t.column :action, :string, null: false
      t.column :audited_changes, :text
      t.column :version, :integer, default: 0, null: false
      t.column :comment, :string
      t.column :remote_address, :string
      t.column :request_uuid, :string
      t.column :created_at, :datetime, null: false
    end

    add_index :audits, [:auditable_id, :auditable_type], name: 'auditable_index', length: {auditable_type: 100}
    add_index :audits, [:associated_id, :associated_type], name: 'associated_index', length: {associated_type: 100}
    add_index :audits, [:user_id, :user_type], name: 'user_index', length: {user_type: 100}
    add_index :audits, :request_uuid, length: {request_uuid: 100}
    add_index :audits, :created_at
  end

  def self.down
    drop_table :audits
  end
end
