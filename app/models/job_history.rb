class JobHistory < ActiveRecord::Base
  scope :active, -> { where(state: ["started", "running"]) }

  belongs_to :project
  belongs_to :user

  has_one :job_lock

  validates :project_id, presence: true

  validates :environment, presence: true,
    inclusion: { in: %w{master1 master2 staging pod1:gamma pod1 pod2:gamma pod2} }

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
    Digest::MD5.hexdigest([
      project.name,
      environment,
      sha,
      created_at
    ].join)
  end

  private

  def lock!
    create_job_lock!(environment: environment, project_id: project_id)
  end

  def unlock!
    job_lock.destroy!
  end
end
