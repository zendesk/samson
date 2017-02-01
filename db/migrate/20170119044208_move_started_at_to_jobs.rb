# frozen_string_literal: true
class MoveStartedAtToJobs < ActiveRecord::Migration[5.0]
  class Job < ActiveRecord::Base
    self.table_name = 'jobs'
    has_one :deploy, class_name: 'MoveStartedAtToJobs::Deploy'
  end

  class Deploy < ActiveRecord::Base
    self.table_name = 'deploys'
    belongs_to :job, class_name: 'MoveStartedAtToJobs::Job'
  end

  def up
    add_column :jobs, :started_at, :datetime
    Job.joins(:deploy).update_all('jobs.started_at = deploys.started_at')
    Job.where(started_at: nil).update_all('started_at = created_at') # assume all old jobs started
    remove_column :deploys, :started_at, :datetime
  end

  def down
    add_column :deploys, :started_at, :datetime
    Deploy.joins(:job).update_all('deploys.started_at = jobs.started_at')
    remove_column :jobs, :started_at, :datetime
  end
end
