class Deploy < ActiveRecord::Base
  belongs_to :stage
  belongs_to :job

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :succeeded?, :failed?, to: :job
  delegate :project, to: :stage

  def summary
    "#{job.user.name} #{summary_action} #{commit} to #{stage.name}"
  end

  def self.active
    joins(:job).where(jobs: { status: %w[pending running] })
  end

  private

  def summary_action
    if pending?
      "is waiting to deploy"
    elsif running?
      "is deploying"
    elsif cancelling?
      "is cancelling a deploy of"
    elsif succeeded?
      "successfully deployed"
    elsif failed?
      "failed to deploy"
    end
  end

  def self.latest_for_project(project_id)
    return limit(10).order("created_at DESC").joins(:job).where(jobs: {project_id: project_id})
  end

  def self.latest_for_stage(stage_id)
    return limit(10).order("created_at DESC").where(stage_id: stage_id)
  end
end
