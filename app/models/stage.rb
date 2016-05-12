class Stage < ActiveRecord::Base
  include Permalinkable
  include HasCommands

  has_soft_deletion default_scope: true unless self < SoftDeletion::Core

  has_paper_trail skip: [:order, :updated_at, :created_at]

  belongs_to :project, touch: true

  has_many :deploys, dependent: :destroy
  has_many :webhooks, dependent: :destroy

  has_one :lock

  has_many :command_associations, autosave: true, class_name: 'StageCommand', dependent: :destroy
  has_many :commands, -> { order('stage_commands.position ASC') },
    through: :command_associations, auto_include: false

  has_many :deploy_groups_stages
  has_many :deploy_groups, through: :deploy_groups_stages

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }

  before_create :ensure_ordering

  def self.reset_order(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index.to_i }
    end
  end

  def self.build_clone(old_stage)
    new(old_stage.attributes.except("id")).tap do |new_stage|
      Samson::Hooks.fire(:stage_clone, old_stage, new_stage)
      new_stage.command_ids = old_stage.command_ids
    end
  end

  def self.unlocked_for(user)
    where("locks.id IS NULL OR locks.user_id = ?", user.id).
    joins("LEFT OUTER JOIN locks ON \
          locks.deleted_at IS NULL AND \
          locks.stage_id = stages.id")
  end

  def self.deployed_on_release
    where(deploy_on_release: true)
  end

  def self.where_reference_being_deployed(reference)
    joins(deploys: :job).where(
      deploys: { reference: reference },
      jobs: { status: Job::ACTIVE_STATUSES }
    )
  end

  def current_deploy
    return @current_deploy if defined?(@current_deploy)
    @current_deploy = deploys.active.first
  end

  def last_deploy
    return @last_deploy if defined?(@last_deploy)
    @last_deploy = deploys.first
  end

  def last_successful_deploy
    return @last_successful_deploy if defined?(@last_successful_deploy)
    @last_successful_deploy = deploys.successful.first
  end

  def locked?
    !!lock && !lock.warning?
  end

  def warning?
    !!lock && lock.warning?
  end

  def locked_for?(user)
    locked? && lock.user != user
  end

  def current_release?(release)
    last_successful_deploy && last_successful_deploy.reference == release.version
  end

  def confirm_before_deploying?
    confirm
  end

  def create_deploy(user, attributes = {})
    deploys.create(attributes.merge(release: !no_code_deployed)) do |deploy|
      deploy.build_job(project: project, user: user, command: script)
    end
  end

  def currently_deploying?
    current_deploy.present?
  end

  # The next stage for the project. If this is the last stage, returns nil.
  def next_stage
    stages = project.stages.to_a
    stages[stages.index(self) + 1]
  end

  def notify_email_addresses
    notify_email_address.split(";").map(&:strip)
  end

  def send_email_notifications?
    notify_email_address.present?
  end

  def global_name
    "#{name} - #{project.name}"
  end

  def send_github_notifications?
    update_github_pull_requests
  end

  def production?
    if DeployGroup.enabled?
      deploy_groups.empty? ? super : deploy_groups.any? { |deploy_group| deploy_group.environment.production? }
    else
      super
    end
  end

  def deploy_requires_approval?
    BuddyCheck.enabled? && !no_code_deployed? && production?
  end

  def automated_failure_emails(deploy)
    return if !email_committers_on_automated_deploy_failure? && static_emails_on_automated_deploy_failure.blank?
    return unless deploy.failed?
    return unless deploy.user.integration?
    last_deploy = deploys.finished_naturally.prior_to(deploy).first
    return if last_deploy.try(:failed?)

    emails = []

    # static notification
    emails.concat static_emails_on_automated_deploy_failure.to_s.split(/, ?/)

    # authors of commits after last successful deploy
    if email_committers_on_automated_deploy_failure?
      changeset = deploy.changeset_to(last_deploy)
      emails.concat changeset.commits.map(&:author_email).compact
    end

    emails.uniq.presence
  end

  def command_updated_at
    [
      command_associations.maximum(:updated_at),
      commands.maximum(:updated_at)
    ].compact.max
  end

  def record_script_change
    record_update true
  end

  def destroy
    mark_for_destruction
    super
  end

  private

  def permalink_base
    name
  end

  def permalink_scope
    Stage.unscoped.where(project_id: project_id)
  end

  def ensure_ordering
    return unless project
    self.order = project.stages.maximum(:order).to_i + 1
  end

  # overwrites papertrail to record script
  def object_attrs_for_paper_trail(attributes)
    super(attributes.merge('script' => script))
  end
end
