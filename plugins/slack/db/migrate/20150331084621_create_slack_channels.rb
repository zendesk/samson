class CreateSlackChannels < ActiveRecord::Migration
  def change
    create_table :slack_channels do |t|
      t.string :name, null: false
      t.string :channel_id, null: false
      t.integer :stage_id, null: false

      t.timestamps
    end

    add_index :slack_channels, :stage_id

  end
end
