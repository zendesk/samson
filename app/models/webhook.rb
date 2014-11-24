class Webhook < ActiveRecord::Base
  has_soft_deletion default_scope: true
  validates :branch, uniqueness: { scope: [ :stage, :deleted_at ], message: "one webhook per (stage, branch) combination." }

  belongs_to :project
  belongs_to :stage

  def self.for_branch(branch)
    where(branch: branch)
  end
end
