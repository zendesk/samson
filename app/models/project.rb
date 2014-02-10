class Project < ActiveRecord::Base
  has_soft_deletion default_scope: true

  validates :name, :repository_url, presence: true
  before_create :generate_token

  has_many :stages
  has_many :deploys, through: :stages
  has_many :jobs, -> { order('created_at DESC') }
  has_many :webhooks
  has_many :commands

  accepts_nested_attributes_for :stages

  scope :alphabetical, -> { order('name') }

  def make_mutex!
    self.with_lock do
      self.update_attributes(:repo_lock => false)
      self.save!
    end
  end

  def take_mutex
    self.with_lock do
      if repo_locked?
        result = :failure
      else
        self.update_attributes(:repo_lock => true)
        self.save!
        result = :success
      end
    end
  end

  def repo_locked?
    self.repo_lock
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def repo_name
    name.parameterize("_")
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
