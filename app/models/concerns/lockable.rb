# frozen_string_literal: true

module Lockable
  extend ActiveSupport::Concern

  included do
    # Lock is deprecated, only gives one lock, locks gives all.
    has_one :lock, as: :resource, dependent: :destroy
    has_many :locks, as: :resource, dependent: :destroy
  end

  def locked_by?(lock)
    lock.global? || lock.resource_equal?(self)
  end
end
