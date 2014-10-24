class Deploy < ActiveRecord::Base
  has_ancestry touch: true
  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :job
  belongs_to :buddy, class_name: 'User'

  default_scope { order(created_at: :desc, id: :desc) }

  validates_presence_of :reference
  validate :validate_stage_is_deployable, on: :create

  delegate :started_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :production?, :project, to: :stage

  def cache_key
    [self, commit]
  end

  def summary
    "#{job.user.name} #{deploy_buddy} #{summary_action} #{short_reference} to #{stage.name} #{nested_deploy_summary}"
  end

  def summary_for_timeline
    "#{short_reference}#{' was' if job.succeeded?} #{summary_action} to #{stage.name}"
  end

  def summary_for_email
    "#{job.user.name} #{summary_action} #{project.name} to #{stage.name} (#{reference})"
  end

  def nested_deploy_summary
    "(as part of a deploy to #{parent.stage.name})" if parent.present?
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

  def buddy
    if buddy_id
      super || NullUser.new(buddy_id)
    else
      nil
    end
  end

  def confirm_buddy!(buddy)
    update_attributes!(buddy: buddy, started_at: Time.now)
    DeployService.new(project, user).confirm_deploy!(self, stage, reference, buddy)
  end

  def start_time
    started_at || created_at
  end

  def pending_non_production?
    pending? && !stage.production?
  end

  def pending_start!
    update_attributes(updated_at: Time.now)       # hack: refresh is immediate with update
    DeployService.new(project, user).confirm_deploy!(self, stage, reference, buddy)
  end

  def waiting_for_buddy?
    pending? && stage.production?
  end

  def can_be_stopped_by?(user)
    started_by?(user) || user.is_admin?
  end

  def self.active
    includes(:job).where(jobs: { status: Job::ACTIVE_STATUSES })
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

  def validate_stage_is_deployable
    if stage.locked_for?(user) || Lock.global.exists?
      errors.add(:stage, 'is locked')
    elsif deploy = stage.current_deploy
      errors.add(:stage, "is being deployed by #{deploy.job.user.name} with #{deploy.short_reference}")
    end
  end

  def deploy_buddy
    return unless BuddyCheck.enabled? && stage.production?

    if buddy.nil? && pending?
      "(waiting for a buddy)"
    elsif buddy.nil? || (user.id == buddy.id)
      "(without a buddy)"
    else
      "(with #{buddy.name})"
    end
  end
end
