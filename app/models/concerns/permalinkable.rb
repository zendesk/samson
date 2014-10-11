module Permalinkable
  def self.included(base)
    base.class_eval do
      validates :permalink, uniqueness: true
      before_create :generate_permalink

      def to_param
        permalink
      end

      def self.find_by_param!(param)
        find_by_permalink!(param)
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
  end
end
