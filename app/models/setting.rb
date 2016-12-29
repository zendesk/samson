# frozen_string_literal: true
class Setting < ActiveRecord::Base
  has_paper_trail skip: [:updated_at, :created_at, :comment]

  validates :name, presence: true, format: /\A[A-Z\d_]+\z/
  after_save :update_cache
  after_destroy :remove_from_cache

  private

  def update_cache
    self.class[name] = value
  end

  def remove_from_cache
    self.class[name] = nil
  end

  class << self
    def [](key)
      cache[key] || ENV[key]
    end

    def []=(k, v)
      cache[k] = v
    end

    private

    def cache
      @cache ||= begin
        @cache = {}
        all.each { |s| s.send :update_cache }
        @cache
      end
    end
  end
end
