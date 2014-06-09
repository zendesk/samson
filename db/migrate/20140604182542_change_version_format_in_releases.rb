class ChangeVersionFormatInReleases < ActiveRecord::Migration
  def up
    rename_column :releases, :number, :version
    change_column :releases, :version, :string, :default => nil, :null => false
  end

  def down
    rename_column :releases, :version, :number
    change_column :releases, :number, :integer, :default => 1
  end
end
