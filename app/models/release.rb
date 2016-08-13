# frozen_string_literal: true
class Release < ActiveRecord::Base
  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true
  belongs_to :build

  before_create :assign_release_number

  # DEFAULT_RELEASE_NUMBER is the default value assigned to release#number by the database.
  # This constant is here for convenience - the value that the database uses is in db/schema.rb.
  DEFAULT_RELEASE_NUMBER = 1

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
    @deployed_stages ||= project.stages.select { |stage| stage.current_release?(self) }
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

  private

  def assign_release_number
    # Detect whether the number has been overwritten by params, e.g. using the
    # release-number-from-ci plugin.
    return if number != DEFAULT_RELEASE_NUMBER && !number.nil?

    latest_release_number = project.releases.last.try(:number) || 0
    self.number = latest_release_number + 1
  end
end
