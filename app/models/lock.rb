# frozen_string_literal: true
class Lock < ActiveRecord::Base
  include ActionView::Helpers::DateHelper
  RESOURCE_TYPES = ['Stage', 'Environment', '', nil].freeze

  attr_reader :delete_in

  has_soft_deletion default_scope: true

  belongs_to :resource, polymorphic: true
  belongs_to :user
  belongs_to :environment

  validates :user_id, presence: true
  validates :description, presence: true, if: :warning?
  validates :resource_type, inclusion: RESOURCE_TYPES
  validate :unique_global_lock, on: :create

  def self.global
    where(resource_id: nil)
  end

  def global?
    !resource_id
  end

  # short summary used in helpers ... keep in sync with locks/_lock.html.erb
  def summary
    "Locked: #{reason} by #{locked_by} #{time_ago_in_words(created_at)} ago#{unlock_summary}"
  end

  def locked_by
    user&.name || 'Unknown user'
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

  def affected
    if resource_type == "Stage"
      "stage"
    elsif resource
      resource.name
    else
      "ALL STAGES"
    end
  end

  # normally there are very few locks, so we grab them all and filter down to avoid lookups
  # sorted by priority(warning) and specificity(type)
  def self.for_resource(resource)
    matching_locks = Lock.select do |lock|
      lock.global? ||
        lock.resource_equal(resource) ||
        (resource.class.name == "Stage" && resource.environments.any? { |e| lock.resource_equal(e) })
    end
    matching_locks.sort_by! { |l| [l.warning? ? 1 : 0, RESOURCE_TYPES.index(l.resource_type)] }
  end

  def self.locked_for?(resource, user)
    locks = for_resource(resource)
    locks.any? { |l| !l.warning? && l.user != user }
  end

  # avoid loading resource if we do not have to, which is uncacheable since it is polymorphic
  def resource_equal(resource)
    resource_id == resource.id && resource_type == resource.class.name
  end

  private

  # our index does not work on nils, so we have to verify by hand
  # we use cheap checks first to avoid .exists? db call
  def unique_global_lock
    errors.add(:resource_id, :invalid) if global? && Lock.global.exists?
  end
end
