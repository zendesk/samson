# frozen_string_literal: true
class AddJenkinsJobsToStage < ActiveRecord::Migration[4.2]
  def change
    change_table :stages do |t|
      t.string :jenkins_job_names
    end
  end
end
