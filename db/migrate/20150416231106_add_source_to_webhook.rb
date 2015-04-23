class AddSourceToWebhook < ActiveRecord::Migration
  def up
    add_column :webhooks, :source, :string, null: false, default: 'any_ci'
    change_column_default :webhooks, :source, nil
  end

  def down
    change_table :webhooks do |t|
      t.remove :source
    end
  end
end
