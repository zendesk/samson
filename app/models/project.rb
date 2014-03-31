class Project < ActiveRecord::Base
  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  before_create :generate_token

  has_many :releases
  has_many :stages
  has_many :deploys, through: :stages
  has_many :jobs, -> { order('created_at DESC') }
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
end
