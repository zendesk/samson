class AddReferenceToJobs < ActiveRecord::Migration
  def change
    change_table :jobs do |t|
      t.string :commit
    end

    change_table :deploys do |t|
      t.rename :commit, :reference
    end
  end
end
