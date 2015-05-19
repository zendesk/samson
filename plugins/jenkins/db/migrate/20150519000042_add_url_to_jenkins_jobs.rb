class AddUrlToJenkinsJobs < ActiveRecord::Migration
  def change
    change_table :jenkins_jobs do |t|
      t.string :url
    end
  end
end
