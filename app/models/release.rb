# frozen_string_literal: true
class Release < ActiveRecord::Base
  NUMBER_REGEX = /\A#{Samson::RELEASE_NUMBER}\z/
  VERSION_REGEX = /\Av(#{Samson::RELEASE_NUMBER})\z/

  belongs_to :project, touch: true, inverse_of: :releases
  belongs_to :author, class_name: "User", inverse_of: false

  before_validation :assign_release_number
  before_validation :convert_ref_to_sha

  validates :number, format: {with: NUMBER_REGEX, message: "may only contain numbers and decimals."}
  validates :commit, format: {with: Build::SHA1_REGEX, message: "can only be a full sha"}, on: :create

  # DEFAULT_RELEASE_NUMBER is the default value assigned to release#number by the database.
  # This constant is here for convenience - the value that the database uses is in db/schema.rb.
  DEFAULT_RELEASE_NUMBER = "1"

  def changeset
    @changeset ||= Changeset.new(project, previous_release&.commit, commit)
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

    errors.add :number, "Unable to auto bump version" unless self.number = next_release_number
  end

  def contains_commit?(other_commit)
    return true if other_commit == commit
    # status values documented here: http://stackoverflow.com/questions/23943855/github-api-to-compare-commits-response-status-is-diverged
    ['behind', 'identical'].include?(GITHUB.compare(project.repository_path, commit, other_commit).status)
  rescue Octokit::NotFound
    false
  rescue Octokit::Error => e
    Samson::ErrorNotifier.notify(
      e, parameters: {
        repository_path: project.repository_path, commit: commit, other_commit: other_commit
      }
    )
    false # Err on side of caution and cause a new release to be created.
  end

  private

  # If Github already has a version tagged for this commit, use it unless it is smaller.
  # If the commit is after a known tag, bump it once.
  # Othervise bump latest release number.
  def next_release_number
    latest_samson_number = project.releases.last&.number || "0"
    next_samson_number = next_number(latest_samson_number)
    return next_samson_number if commit.blank?

    return next_samson_number unless fuzzy_tag = project.repository.fuzzy_tag_from_ref(commit)&.split('-', 2)
    return next_samson_number unless latest_github_number = fuzzy_tag.first[VERSION_REGEX, 1]
    next_github_number = (fuzzy_tag.size == 1 ? latest_github_number : next_number(latest_github_number))

    if Gem::Version.new(next_samson_number) > Gem::Version.new(next_github_number)
      next_samson_number
    else
      next_github_number
    end
  end

  def next_number(current_version)
    current_version.to_s.dup.sub!(/\d+$/) { |d| d.to_i + 1 }
  end

  def convert_ref_to_sha
    return if commit.blank? || commit =~ Build::SHA1_REGEX
    self.commit = project.repo_commit_from_ref(commit)
  end
end
Samson::Hooks.load_decorators(Release)
