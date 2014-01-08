class Webhook < ActiveRecord::Base
  belongs_to :project
  belongs_to :stage

  def self.for_branch(branch)
    where(branch: branch)
  end
end
