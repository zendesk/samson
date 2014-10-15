module Permalinkable
  extend ActiveSupport::Concern

  included do
    validates :permalink, uniqueness: true
    before_create :generate_permalink
  end

  module ClassMethods
    def find_by_param!(param)
      find_by_permalink!(param)
    end
  end

  def to_param
    permalink
  end

  private

  def generate_permalink
    base = permalink_base.downcase
    self.permalink = base
    if self.class.where(permalink: permalink).exists?
      self.permalink = "#{base}-#{SecureRandom.hex(4)}"
    end
  end
end
