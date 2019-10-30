# frozen_string_literal: true

class AddExternalSetupHooks < ActiveRecord::Migration[5.2]
  def change
    create_table :external_setup_hooks do |t|
      t.string :name, null: false
      t.string :description, default: '', null: false
      t.string :endpoint, null: false
      t.string :auth_type, null: false
      t.string :auth_token, null: false
      t.boolean :verify_ssl, default: true, null: false
    end
  end
end
