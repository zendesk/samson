class JobTextUpgrade < ActiveRecord::Migration
  def change
    change_column :jobs, :output, :text, :limit => 1.gigabyte - 1
  end
end
