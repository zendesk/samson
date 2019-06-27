# frozen_string_literal: true
class Lock < ActiveRecord::Base
  include ActionView::Helpers::DateHelper
  RESOURCE_TYPES = ['Stage', 'Project', 'DeployGroup', 'Environment', nil].freeze # sorted by specificity
  CACHE_KEY = 'lock-cache-key'
  ALL_CACHE_KEY = 'lock-all'

  attr_reader :delete_in

  has_soft_deletion default_scope: true

  include SoftDeleteWithDestroy

  belongs_to :resource, polymorphic: true, optional: true
  belongs_to :user, inverse_of: :locks
  belongs_to :environment, optional: true

  before_validation :nil_out_blank_resource_type

  validates :user_id, presence: true
  validates :description, presence: true, if: :warning?
  validates :resource_type, inclusion: RESOURCE_TYPES
  validate :unique_global_lock, on: :create
  validate :valid_delete_at, on: :create

  after_save :expire_all_cached

  class << self
    def global
      all_cached.select(&:global?)
    end

    # normally there are very few locks, so we grab them all and filter down to avoid lookups
    # sorted by priority(warning) and specificity(type)
    def for_resource(resource)
      matching_locks = all_cached.select { |l| resource.locked_by?(l) }
      matching_locks.sort_by! { |l| [l.warning? ? 1 : 0, RESOURCE_TYPES.index(l.resource_type)] }
    end

    def locked_for?(resource, user)
      locks = for_resource(resource)
      locks.any? { |l| !l.warning? && l.user.id != user&.id }
    end

    def cache_key
      Rails.cache.fetch(CACHE_KEY) { Time.now.to_f }
    end

    def remove_expired_locks
      Lock.where("delete_at IS NOT NULL and delete_at < ?", Time.now).find_each(&:soft_delete!)
    end

    private

    def all_cached
      Rails.cache.fetch(ALL_CACHE_KEY) { all.to_a }
    end
  end

  def global?
    !resource_id
  end

  # short summary used in helpers ... keep in sync with locks/_lock.html.erb
  def summary
    "#{warning ? "Warning" : "Locked"}: #{reason} by #{locked_by} #{time_ago_in_words(created_at)} ago#{expire_summary}"
  end

  def locked_by
    user&.name || 'Unknown user'
  end

  def expire_summary
    return unless delete_at
    if Samson::Periodical.overdue?(:remove_expired_locks, delete_at)
      " and expiration is not working"
    else
      time = (block_given? ? yield(delete_at) : "in #{time_ago_in_words(delete_at)}")
      " and will expire ".html_safe << time
    end
  end

  def reason
    description.presence || "Description not given"
  end

  # avoid loading resource if we do not have to, which is uncacheable since it is polymorphic
  def resource_equal?(resource)
    resource_id == resource.id && resource_type == resource.class.name
  end

  def delete_in=(seconds)
    self.delete_at = seconds.present? ? Time.now + seconds.to_i : nil
  end

  private

  def expire_all_cached
    Rails.cache.delete CACHE_KEY
    Rails.cache.delete ALL_CACHE_KEY
  end

  def nil_out_blank_resource_type
    self.resource_type = resource_type.presence
  end

  # our index does not work on nils, so we have to verify by hand
  def unique_global_lock
    errors.add(:resource_id, :invalid) if global? && Lock.global.first
  end

  def valid_delete_at
    errors.add(:delete_at, 'Date must be in the future') if delete_at&.past?
  end
end
