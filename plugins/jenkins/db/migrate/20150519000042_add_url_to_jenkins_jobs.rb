# frozen_string_literal: true
class AddUrlToJenkinsJobs < ActiveRecord::Migration[4.2]
  def change
    change_table :jenkins_jobs do |t|
      t.string :url
    end
  end
end
