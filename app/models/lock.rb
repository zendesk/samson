# frozen_string_literal: true
class Lock < ActiveRecord::Base
  include ActionView::Helpers::DateHelper

  attr_reader :delete_in

  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :user

  validates :user_id, presence: true
  validates :description, presence: true, if: :warning?
  validate :unique_global_lock, on: :create

  def self.global
    where(stage_id: nil)
  end

  def global?
    stage_id.blank?
  end

  # short summary used in helpers ... keep in sync with locks/_lock.html.erb
  def summary
    "Locked: #{reason} by #{locked_by} #{time_ago_in_words(created_at)} ago#{unlock_summary}"
  end

  def locked_by
    (user.try(:name) || 'Unknown user').to_s
  end

  def unlock_summary
    return unless delete_at
    if delete_at < (Samson::Tasks::LockCleaner::INTERVAL * 2).seconds.ago
      " and automatic unlock is not working"
    else
      " and will unlock in #{time_ago_in_words(delete_at)}"
    end
  end

  def reason
    description.blank? ? "Description not given" : description
  end

  def self.remove_expired_locks
    Lock.where("delete_at IS NOT NULL and delete_at < CURRENT_TIMESTAMP").find_each(&:soft_delete!)
  end

  def delete_in=(seconds)
    self.delete_at = seconds.present? ? Time.now + seconds.to_i : nil
  end

  private

  def unique_global_lock
    errors.add(:stage_id, :invalid) if global? && Lock.global.exists?
  end
end
