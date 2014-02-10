class Deploy < ActiveRecord::Base
  belongs_to :stage
  belongs_to :job

  default_scope { order(created_at: :desc, id: :desc) }

  validates_presence_of :reference
  validate :stage_is_unlocked

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :project, to: :stage

  def cache_key
    [self, commit]
  end

  def summary
    "#{job.user.name} #{summary_action} #{short_reference} to #{stage.name}"
  end

  def summary_for_email
    "#{job.user.name} #{summary_action} #{project.name} to #{stage.name} (#{reference})"
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

  def changeset
    @changeset ||= Changeset.find(project.github_repo, previous_commit, commit)
  end

  def self.active
    includes(:job).where(jobs: { status: %w[pending running] })
  end

  def self.running
    includes(:job).where(jobs: { status: 'running' })
  end

  def self.successful
    includes(:job).where(jobs: { status: 'succeeded' })
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
      "is cancelling a deploy"
    elsif cancelled?
      "cancelled a deploy"
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
