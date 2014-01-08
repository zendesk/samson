require 'soft_deletion'

class Project < ActiveRecord::Base
  has_soft_deletion

  validates_presence_of :name
  before_create :generate_token

  has_many :stages
  has_many :deploys, -> { order('created_at DESC') }, through: :stages
  has_many :jobs, -> { order('created_at DESC') }
  has_many :webhooks

  accepts_nested_attributes_for :stages

  def to_param
    "#{id}-#{name.parameterize}"
  end

  def repo_name
    name.parameterize("_")
  end

  def webhook_stages_for_branch(branch)
    webhooks.for_branch(branch).map(&:stage)
  end

  private

  def generate_token
    self.token = SecureRandom.hex
  end
end
