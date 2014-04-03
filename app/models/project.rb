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
    latest_release_number = releases.last.try(:number) || 0
    release_number = latest_release_number + 1
    releases.create(attrs.merge(number: release_number))
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
    repository_url.scan(/:(\w+\/\w+)\.git$/).join
  end

  def repository_homepage
    "//github.com/#{github_repo}"
  end

  def webhook_stages_for_branch(branch)
    webhooks.for_branch(branch).map(&:stage)
  end

  private

  def generate_token
    self.token = SecureRandom.hex
  end

  def release_prior_to(release)
    releases.where("number < ?", release.number).order(:number).last
  end
end
