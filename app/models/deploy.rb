class Deploy < ActiveRecord::Base
  belongs_to :stage
  belongs_to :job

  default_scope { order('created_at DESC, id DESC') }

  validates_presence_of :reference
  validate :stage_is_unlocked

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :project, to: :stage

  def summary
    "#{job.user.name} #{summary_action} #{short_reference} to #{stage.name}"
  end

  def commit
    job.try(:commit).presence || reference
  end

  def short_reference
    if reference =~ /\A[0-9a-f]{40}\Z/
      reference[0...7]
    else
      reference
    end
  end

  def previous_deploy
    stage.deploys.successful.prior_to(self).first
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
    elsif cancelled?
      "cancelled a deploy of"
    elsif succeeded?
      "deployed"
    elsif failed?
      "failed to deploy"
    elsif errored?
      "encountered an error deploying"
    end
  end

  def stage_is_unlocked
    if stage.locked? || Lock.global.exists?
      errors.add(:stage, 'is locked')
    end
  end
end
