class Deploy < ActiveRecord::Base

  belongs_to :stage
  belongs_to :job

  default_scope { order('created_at DESC') }

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :project, to: :stage

  def summary
    "#{job.user.name} #{summary_action} #{reference} to #{stage.name}"
  end

  def commit
    job.try(:commit).presence || reference
  end

  def previous_deploy
    stage.deploys.successful.prior_to(self).last
  end

  def previous_commit
    previous_deploy.try(:commit)
  end

  def self.active
    joins(:job).where(jobs: { status: %w[pending running] })
  end

  def self.running
    joins(:job).where(jobs: { status: "running" })
  end

  def self.successful
    joins(:job).where(jobs: { status: %w[succeeded] })
  end

  def self.prior_to(deploy)
    where("#{table_name}.id < ?", deploy.id)
  end

  private

  def summary_action
    if pending?
      "is about to deploy"
    elsif running?
      "is deploying"
    elsif cancelling?
      "is cancelling a deploy of"
    elsif succeeded?
      "deployed"
    elsif failed?
      "failed to deploy"
    elsif errored?
      "encountered an error deploying"
    end
  end

end
