class JobLock < ActiveRecord::Base
  extend EnvironmentsHelper

  default_scope { where("expires_at IS NULL OR expires_at >= ?", Time.now) }

  validates :environment, presence: true,
    inclusion: { in: valid_environments }

  belongs_to :project
  belongs_to :job_history

  validates :project_id, presence: true
  validates :job_history_id, presence: true, if: ->(jl) { jl.expires_at.nil? }
  validates :expires_at, presence: true, if: ->(jl) { jl.job_history_id.nil? }

  def expires_at=(val)
    write_attribute(:expires_at, DateTime.parse(val))
  rescue ArgumentError
  end
end
