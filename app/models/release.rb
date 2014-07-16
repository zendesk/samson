class Release < ActiveRecord::Base

  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true

  validates :version, presence: true, uniqueness: { scope: :project_id }

  def self.sort_by_version
    order(version: :desc)
  end

  def self.next_version_for(project, bump_type = 'default')
    latest_version = project.releases.last.try(:version)

    if latest_version
      Version.new(project.versioning_schema, latest_version).bump.to_s
    else
      Version.new(project.versioning_schema).to_s
    end
  end

  def to_param
    version
  end

  def deployed_stages
    @deployed_stages ||= project.stages.select {|stage| stage.current_release?(self) }
  end

  def changeset
    @changeset ||= Changeset.find(project.github_repo, previous_release.try(:commit), commit)
  end

  def previous_release
    project.release_prior_to(self)
  end

end
