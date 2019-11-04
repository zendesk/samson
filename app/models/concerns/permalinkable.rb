# frozen_string_literal: true
module Permalinkable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_permalink, on: :create
    validates :permalink, presence: true, format: /\A[a-z0-9\-_]*\z/
    validate :validate_unique_permalink

    # making permalink and soft-delete dependent is a bit weird, but if a model is important enough to have a permalink
    # then it should also be soft_deleted ... also otherwise setup order is non obvious and could fail silently
    around_soft_delete :free_permalink_for_deletion
  end

  module ClassMethods
    # find by permalink or id
    def find_by_param(param)
      param = param.to_s
      if param.match?(/^\d+$/)
        find_by("permalink = ? OR id = ?", param, param)
      else
        find_by(permalink: param)
      end
    end

    def find_by_param!(param)
      find_by_param(param) || raise(ActiveRecord::RecordNotFound)
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
    return if permalink.present?
    base = permalink_base.to_s.parameterize
    self.permalink = base
    self.permalink = "#{base}-#{SecureRandom.hex(4)}" if permalink_taken?
  end

  def permalink_taken?
    scope = permalink_scope.where(permalink: permalink)
    scope = scope.where.not(id: id) if persisted?
    scope.exists?
  end

  def validate_unique_permalink
    errors.add(:permalink, :taken) if permalink_taken?
  end

  def free_permalink_for_deletion
    self.permalink = "#{permalink}-deleted-#{Time.now.to_i}"
    success = yield
    self.permalink = permalink_was unless success
    success
  rescue StandardError
    self.permalink = permalink_was
    raise
  end
end
