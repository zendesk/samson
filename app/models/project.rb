class Project < ActiveRecord::Base
  validates_presence_of :name

  has_many :job_histories, -> { order("created_at DESC") }
  has_many :job_locks, -> { order("created_at DESC") }

  def to_param
    "#{id}-#{name.parameterize}"
  end
end
