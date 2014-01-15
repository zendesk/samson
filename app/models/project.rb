require 'soft_deletion'

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

  def webhook_stages_for_branch(branch)
    webhooks.for_branch(branch).map(&:stage)
  end

  private

  def generate_token
    self.token = SecureRandom.hex
  end
end
