class Project < ActiveRecord::Base
  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  before_create :generate_token

  has_many :releases
  has_many :stages
  has_many :deploys, through: :stages
  has_many :jobs, -> { order(created_at: :desc) }
  has_many :webhooks
  has_many :commands

  accepts_nested_attributes_for :stages

  scope :alphabetical, -> { order('name') }

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def repo_name
    name.parameterize("_")
  end

  # Creates a new Release, incrementing the release number. If the Release
  # fails to save, `#persisted?` will be false.
  #
  # Returns the Release.
  def create_release(attrs = {})
    release = build_release(attrs)
    release.save
    release
  end

  def build_release(attrs = {})
    attrs[:version] ||= Release.next_version_for(self)
    releases.build(attrs)
  end

  def auto_release_stages
    stages.deployed_on_release
  end

  def manage_releases?
    releases.any?
  end

  # Whether to create new releases when the branch is updated.
  #
  # branch - The String name of the branch in question.
  #
  # Returns true if new releases should be created, false otherwise.
  def create_releases_for_branch?(branch)
    release_branch == branch
  end

  def changeset_for_release(release)
    prior_release = release_prior_to(release)
    prior_commit = prior_release && prior_release.commit
    Changeset.find(github_repo, prior_commit, release.commit)
  end

  # The user/repo part of the repository URL.
  def github_repo
    # GitHub allows underscores, hyphens and dots in repo names
    # but only hyphens in user/organisation names (as well as alphanumeric).
    repository_url.scan(/:([A-Za-z0-9-]+\/[\w.-]+)\.git$/).join
  end

  def repository_homepage
    "//#{Rails.application.config.samson.github.web_url}/#{github_repo}"
  end

  def webhook_stages_for_branch(branch)
    webhooks.for_branch(branch).map(&:stage)
  end

  def release_prior_to(release)
    releases.where("version < ?", release.version).order(:version).last
  end

  private

  def generate_token
    self.token = SecureRandom.hex
  end
end
