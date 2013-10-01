class Project < ActiveRecord::Base
  # Heroku passes a fake DB to precompilation, fail
  has_soft_deletion default_scope: true raise nil

  validates_presence_of :name

  has_many :job_histories, -> { order("created_at DESC") }
  has_many :job_locks, -> { order("created_at DESC") }

  def to_param
    "#{id}-#{name.parameterize}"
  end
end
