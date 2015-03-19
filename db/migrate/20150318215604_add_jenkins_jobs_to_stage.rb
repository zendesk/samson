class AddJenkinsJobNamesToStage < ActiveRecord::Migration
  def change
    change_table :stages do |t|
      t.string :jenkins_job_names
    end
  end
end
