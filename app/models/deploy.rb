class Deploy < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :job
  belongs_to :buddy, class_name: 'User'

  default_scope { order(created_at: :desc, id: :desc) }

  validates_presence_of :reference
  validate :stage_is_unlocked

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :production?, :project, to: :stage

  def cache_key
    [self, commit]
  end

  def summary
    "#{job.user.name} #{summary_action} #{short_reference} to #{stage.name} #{buddy_info}"
  end

  def summary_for_timeline
    "#{short_reference}#{' was' if job.succeeded?} #{summary_action} to #{stage.name} #{buddy_info}"
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

  def production
    stage.production?
  end

  def confirm_buddy!(buddy)
    update_attributes(buddy: buddy, started_at: Time.now)
    DeployService.new(project, user).confirm_deploy!(self, stage, reference, buddy)
  end

  def canceled_by_buddy!(buddy)
    update_attributes(buddy: buddy)
  end

  def pending_non_production?
    pending? && !stage.production?
  end

  def pending_start!()
    update_attributes(updated_at: Time.now)       # hack: refresh is immediate with update
    DeployService.new(project, user).confirm_deploy!(self, stage, reference, buddy)
  end

  def waiting_for_buddy?
    pending? && stage.production?
  end

  def can_be_stopped_by?(user)
    started_by?(user) || user.is_admin? || (waiting_for_buddy? && user.is_deployer?)
  end

  def self.active
    includes(:job).where(jobs: { status: %w[pending running cancelling] })
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

  def self.expired
    threshold = BuddyCheck.deploy_max_minutes_pending.minutes.ago
    joins(:job).where(jobs: { status: 'pending'} ).where("jobs.created_at < ?", threshold)
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

  def buddy_info
    if self.buddy
      "(vetted by #{self.buddy.name})"
    end
  end

  def stage_is_unlocked
    if stage.locked? || Lock.global.exists?
      errors.add(:stage, 'is locked')
    end
  end
end
