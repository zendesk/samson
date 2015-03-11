class Release < ActiveRecord::Base
  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true

  def self.sort_by_version
    order(number: :desc)
  end

  def to_param
    version
  end

  def currently_deploying_stages
    project.stages.where_reference_being_deployed(version)
  end

  def deployed_stages
    @deployed_stages ||= project.stages.select {|stage| stage.current_release?(self) }
  end

  def changeset
    @changeset ||= Changeset.new(project.github_repo, previous_release.try(:commit), commit)
  end

  def previous_release
    project.release_prior_to(self)
  end

  def version
    "v#{number}"
  end

  def author
    super || NullUser.new(author_id)
  end

  def self.find_by_version!(version)
    find_by_number!(version[/\Av(\d+)\Z/, 1].to_i)
  end
end
