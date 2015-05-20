class Build < ActiveRecord::Base
  SHA1_REGEX = /\A[0-9a-f]{40}\Z/i

  belongs_to :project
  has_many :statuses, class_name: 'BuildStatus'
  has_many :deploys
  has_many :releases

  validates :project, presence: true
  validates :git_sha, format: SHA1_REGEX, allow_nil: true
  validates :container_sha, format: SHA1_REGEX, allow_nil: true

  def successful?
    statuses.all?(&:successful?)
  end
end
