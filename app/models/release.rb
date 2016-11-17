# frozen_string_literal: true
class Release < ActiveRecord::Base
  NUMBER = '\d+(:?.\d+)*'
  NUMBER_REGEX = /\A#{NUMBER}\z/
  VERSION_REGEX = /\Av(#{NUMBER})\z/

  belongs_to :project, touch: true
  belongs_to :author, polymorphic: true
  belongs_to :build # direct association is not necessary since the release commit is the same as the build sha

  before_validation :assign_release_number
  before_validation :covert_ref_to_sha

  validates :number, format: { with: NUMBER_REGEX, message: "may only contain numbers and decimals." }
  validates :commit, format: { with: Build::SHA1_REGEX, message: "can only be a full sha"}, on: :create

  # DEFAULT_RELEASE_NUMBER is the default value assigned to release#number by the database.
  # This constant is here for convenience - the value that the database uses is in db/schema.rb.
  DEFAULT_RELEASE_NUMBER = "1"

  def currently_deploying_stages
    project.stages.where_reference_being_deployed(version)
  end

  def changeset
    @changeset ||= Changeset.new(project.github_repo, previous_release.try(:commit), commit)
  end

  def previous_release
    project.release_prior_to(self)
  end

  def author
    super || NullUser.new(author_id)
  end

  def to_param
    version
  end

  def self.find_by_param!(version)
    if number = version[VERSION_REGEX, 1]
      find_by_number!(number)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def version
    "v#{number}"
  end

  def assign_release_number
    # Detect whether the number has been overwritten by params, e.g. using the
    # release-number-from-ci plugin.
    return if number != DEFAULT_RELEASE_NUMBER && number.present?

    latest_release_number = project.releases.last.try(:number) || "0"

    raise "Unable to auto bump version" unless self.number = latest_release_number.dup.sub!(/\d+$/) { |d| d.to_i + 1 }
  end

  def contains_commit?(other_commit)
    return true if other_commit == commit
    # status values documented here: http://stackoverflow.com/questions/23943855/github-api-to-compare-commits-response-status-is-diverged
    GITHUB.compare(project.github_repo, commit, other_commit).status == 'behind'
  rescue Octokit::NotFound
    false
  rescue Octokit::Error => e
    Airbrake.notify(e, parameters: { github_repo: project.github_repo, commit: commit, other_commit: other_commit})
    false # Err on side of caution and cause a new release to be created.
  end

  private

  def covert_ref_to_sha
    return if commit.blank? || commit =~ Build::SHA1_REGEX

    # Create/update local cache to avoid getting a stale reference
    project.repository.exclusive(holder: 'Release#covert_ref_to_sha', &:update_local_cache!)
    self.commit = project.repository.commit_from_ref(commit)
  end
end
