class AddKuberetesToStage < ActiveRecord::Migration
  def change
    add_column :deploys, :kubernetes, :boolean, default: false, null: false
  end
end
