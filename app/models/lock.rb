# frozen_string_literal: true
class Lock < ActiveRecord::Base
  include ActionView::Helpers::DateHelper
  RESOURCE_TYPES = ['Stage', 'Environment', nil].freeze # sorted by specificity
  CACHE_KEY = 'lock-cache-key'
  ALL_CACHE_KEY = 'lock-all'
  ASSIGNABLE_KEYS = [:description, :resource_id, :resource_type, :warning, :delete_in].freeze

  attr_reader :delete_in

  has_soft_deletion default_scope: true

  belongs_to :resource, polymorphic: true
  belongs_to :user
  belongs_to :environment

  before_validation :nil_out_blank_resource_type

  validates :user_id, presence: true
  validates :description, presence: true, if: :warning?
  validates :resource_type, inclusion: RESOURCE_TYPES
  validate :unique_global_lock, on: :create

  after_save :expire_all_cached

  def self.global
    all_cached.select(&:global?)
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
      " and will expire in #{time_ago_in_words(delete_at)}"
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
    matching_locks = all_cached.select { |l| l.send(:matches_resource?, resource) }
    matching_locks.sort_by! { |l| [l.warning? ? 1 : 0, RESOURCE_TYPES.index(l.resource_type)] }
  end

  def self.locked_for?(resource, user)
    locks = for_resource(resource)
    locks.any? { |l| !l.warning? && l.user != user }
  end

  def self.cache_key
    Rails.cache.fetch(CACHE_KEY) { Time.now.to_f }
  end

  private_class_method def self.all_cached
    Rails.cache.fetch(ALL_CACHE_KEY) { all.to_a }
  end

  private

  def matches_resource?(resource)
    global? ||
      resource_equal(resource) ||
      (
        resource_type == "Environment" &&
        resource.is_a?(Stage) &&
        resource.environments.any? { |e| resource_equal(e) }
      )
  end

  # avoid loading resource if we do not have to, which is uncacheable since it is polymorphic
  def resource_equal(resource)
    resource_id == resource.id && resource_type == resource.class.name
  end

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
end
