# frozen_string_literal: true

module Lockable
  extend ActiveSupport::Concern

  included do
    has_many :lock, as: :resource, dependent: :destroy
  end

  def locked_by?(lock)
    lock.global? || lock.resource_equal?(self)
  end
end
