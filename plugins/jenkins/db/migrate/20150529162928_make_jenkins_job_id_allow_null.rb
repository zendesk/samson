# frozen_string_literal: true
class MakeJenkinsJobIdAllowNull < ActiveRecord::Migration[4.2]
  def change
    change_column_null :jenkins_jobs, :jenkins_job_id, true
  end
end
