module Permalinkable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_permalink, on: :create
    validates :permalink, presence: true
    validate :validate_unique_permalink
  end

  module ClassMethods
    def find_by_param!(param)
      find_by_permalink!(param)
    rescue ActiveRecord::RecordNotFound
      if param =~ /^\d+$/
        find_by_id!(param)
      else
        raise
      end
    end
  end

  def to_param
    permalink
  end

  private

  def permalink_scope
    self.class.unscoped
  end

  def generate_permalink
    base = permalink_base.to_s.parameterize
    self.permalink = base
    if permalink_taken?
      self.permalink = "#{base}-#{SecureRandom.hex(4)}"
    end
  end

  def permalink_taken?
    scope = permalink_scope.where(permalink: permalink)
    scope = scope.where("id <> ?", id) if persisted?
    scope.exists?
  end

  def validate_unique_permalink
    errors.add(:permalink, :taken) if permalink_taken?
  end
end
