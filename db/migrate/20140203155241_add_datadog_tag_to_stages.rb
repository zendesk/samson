class AddDatadogTagToStages < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :datadog_tags
    end
  end
end
