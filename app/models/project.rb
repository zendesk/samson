class Project < ActiveRecord::Base
  has_soft_deletion :default_scope => true

  validates_presence_of :name

  has_many :job_histories
  has_many :job_locks
end
