class Webhook < ActiveRecord::Base
  has_soft_deletion default_scope: true
  validates :branch, uniqueness: { scope: [ :stage ], conditions: -> { where("deleted_at IS NULL") }, message: "one webhook per (stage, branch) combination." }

  belongs_to :project
  belongs_to :stage

  def self.for_branch(branch)
    where(branch: branch)
  end

  def self.for_source(service_type, service_name)
    where(source: [ 'any', "any_#{service_type}", service_name ])
  end
end
