class Project < ActiveRecord::Base
  has_soft_deletion default_scope: true

  validates_presence_of :name

  has_many :job_histories, -> { order("created_at DESC") }
  has_many :job_locks, -> { order("created_at DESC") }
end
