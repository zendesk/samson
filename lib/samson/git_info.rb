# frozen_string_literal: true
module Samson
  module GitInfo
    class << self
      def version
        @version ||= begin
          version = `git --version`
          raise "Error fetching git version" unless $?.success?
          Gem::Version.new(version.scan(/\d+/).join('.'))
        end
      end
    end
  end
end
