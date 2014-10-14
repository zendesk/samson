class Webhook < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :project
  belongs_to :stage

  def self.for_branch(branch)
    where(branch: branch)
  end
end
