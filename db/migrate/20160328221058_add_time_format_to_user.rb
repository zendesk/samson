class AddTimeFormatToUser < ActiveRecord::Migration
  def change
    add_column :users, :time_format, :string, default: 'relative', null: false
  end
end
