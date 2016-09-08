# frozen_string_literal: true
class AddReferenceToJobs < ActiveRecord::Migration[4.2]
  def change
    change_table :jobs do |t|
      t.string :commit
    end

    change_table :deploys do |t|
      t.rename :commit, :reference
    end
  end
end
