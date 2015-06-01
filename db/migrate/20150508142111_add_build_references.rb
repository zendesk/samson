class AddBuildReferences < ActiveRecord::Migration
  def change
    change_table :deploys do |t|
      t.belongs_to :build, index: true
    end

    change_table :releases do |t|
      t.belongs_to :build, index: true
    end
  end
end
