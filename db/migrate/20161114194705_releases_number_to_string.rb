class ReleasesNumberToString < ActiveRecord::Migration[5.0]
  def change
    change_column :releases, :number, :string, limit: 255, default: "1", null: false
  end
end
