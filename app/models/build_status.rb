class BuildStatus < ActiveRecord::Base
  SUCCESSFUL = 'successful'.freeze
  PENDING    = 'pending'.freeze
  FAILED     = 'failed'.freeze

  VALID_STATUSES = [SUCCESSFUL, PENDING, FAILED]

  belongs_to :build

  validates :build, presence: true
  validates :status, presence: true, inclusion: VALID_STATUSES

  VALID_STATUSES.each do |s|
    define_singleton_method s do
      where(status: s)
    end

    define_method "#{s}?" do
      self.status == s
    end
  end
end
