class Release < ActiveRecord::Base
  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true

  def self.sort_by_newest
    order("created_at DESC")
  end

  def deployed_stages
    @deployed_stages ||= project.stages.select {|stage| stage.current_release?(self) }
  end

  def version
    "v#{number}"
  end
end
