class Lock < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :stage
  belongs_to :user

  validates :user_id, presence: true
  validate :unique_global_lock, on: :create

  def self.global
    where(stage_id: nil)
  end

  def global?
    stage_id.blank?
  end

  private

  def unique_global_lock
    if global? && Lock.global.exists?
      errors.add(:stage_id, :invalid)
    end
  end
end
