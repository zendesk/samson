class Lock < ActiveRecord::Base
  include ActionView::Helpers::DateHelper

  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :user

  validates :user_id, presence: true
  validate :unique_global_lock, on: :create

  def self.global
    where(stage_id: nil)
  end

  def global?
    stage_id.blank?
  end

  def summary
    "Locked by #{self.user.name} #{time_ago_in_words(self.created_at)} ago"
  end

  def reason
    return "Description not given." if description.empty?
    description.capitalize
  end

  private

  def unique_global_lock
    if global? && Lock.global.exists?
      errors.add(:stage_id, :invalid)
    end
  end
end
