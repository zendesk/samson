class JobLock < ActiveRecord::Base
  default_scope { where("expires_at IS NULL OR expires_at >= ?", Time.now) }

  validates :environment, presence: true,
    inclusion: { in: %w{master1 master2 staging pod1:gamma pod1 pod2:gamma pod2} }

  belongs_to :project
  belongs_to :job_history

  validates :project_id, presence: true
  validates :job_history_id, presence: true, if: ->(jl) { jl.expires_at.nil? }
  validates :expires_at, presence: true, if: ->(jl) { jl.job_history_id.nil? }
end
