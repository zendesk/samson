require 'soft_deletion'

class Project < ActiveRecord::Base
  # Heroku passes a fake DB to precompilation, fail
  begin
    has_soft_deletion
  rescue
  end

  validates_presence_of :name

  has_many :job_histories, -> { order("created_at DESC") }
  has_many :job_locks, -> { order("created_at DESC") }

  before_create :set_default_environments
  after_create :update_project_environments, unless: -> { Rails.env.test? }

  serialize :environments

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def repo_name
    name.parameterize("_")
  end

  def environments
    read_attribute(:environments) || []
  end

  private

  def set_default_environments
    self.environments ||= %w{master1 master2 staging qa pod1 pod1:gamma pod2 pod2:gamma pod3 pod3:gamma}
  end

  def update_project_environments
    EnvironmentUpdater.new(Project.all).run
  end
end
