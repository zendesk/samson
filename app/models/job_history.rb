require 'state_machine'

class JobHistory < ActiveRecord::Base
  extend EnvironmentsHelper

  scope :active, -> { where(state: ["started", "running"]) }

  belongs_to :project
  belongs_to :user

  has_one :job_lock

  before_create :set_channel

  validate :unlocked_project, on: :create

  validates :project_id, presence: true

  validates :sha, presence: true

  validates :environment, presence: true,
    inclusion: { in: valid_environments }

  validates_uniqueness_of :state, scope: [:environment, :project_id],
    conditions: -> { where(state: "running") }

  state_machine initial: :started do
    before_transition started: :running, do: :lock!
    before_transition to: [:successful, :failed], do: :unlock!

    event :run do
      transition :started => :running
    end

    event :success do
      transition :running => :successful
    end

    event :failed do
      transition :running => :failed
    end
  end

  def locked?
    job_lock.exists?
  end

  def channel
    read_attribute(:channel) ||
      "deploy:" + Digest::MD5.hexdigest([
        project.name,
        environment,
        sha,
        created_at
      ].join)
  end

  def to_param
    channel
  end

  private

  def lock!
    create_job_lock!(environment: environment, project_id: project_id)
  end

  def unlock!
    job_lock.destroy!
  end

  def set_channel
    write_attribute(:channel, channel)
  end

  def unlocked_project
    lock = project.job_locks.where(environment: environment).first
    return unless lock
    errors.add(:environment, "is locked")
  end
end
