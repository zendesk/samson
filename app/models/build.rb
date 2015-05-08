class Build < ActiveRecord::Base
  SHA1_REGEX = /\A[0-9a-f]{40}/i

  belongs_to :project
  has_many :deploys
  has_many :releases

  validates :project, presence: true
  validates :git_sha, format: SHA1_REGEX, allow_nil: true
  validates :container_sha, format: SHA1_REGEX, allow_nil: true
end
