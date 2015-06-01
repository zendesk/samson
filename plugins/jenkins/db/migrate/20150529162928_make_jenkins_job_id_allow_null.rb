class MakeJenkinsJobIdAllowNull < ActiveRecord::Migration
  def change
    change_column_null :jenkins_jobs, :jenkins_job_id, true
  end
end
