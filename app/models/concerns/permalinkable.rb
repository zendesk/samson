# frozen_string_literal: true
module Permalinkable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_permalink, on: :create
    validates :permalink, presence: true
    validate :validate_unique_permalink
  end

  module ClassMethods
    # find by permalink or id
    def find_by_param(param)
      param = param.to_s
      if param =~ /^\d+$/
        where("permalink = ? OR id = ?", param, param).first
      else
        where(permalink: param).first
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
    base = permalink_base.to_s.parameterize
    self.permalink = base
    self.permalink = "#{base}-#{SecureRandom.hex(4)}" if permalink_taken?
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
