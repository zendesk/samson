class Release < ActiveRecord::Base
  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true

  def self.sort_by_version
    order(number: :desc)
  end

  def deployed_stages
    @deployed_stages ||= project.stages.select {|stage| stage.current_release?(self) }
  end

  def version
    "v#{number}"
  end
end
