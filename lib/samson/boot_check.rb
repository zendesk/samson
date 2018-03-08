# frozen_string_literal: true
module Samson
  module BootCheck
    class << self
      def check
        if ENV['SERVER_MODE']
          # make sure nobody uses connections on the main thread since they will block reloading in dev
          10.times do |i|
            break if ActiveRecord::Base.connection_pool.stat.fetch(:busy).zero?
            if i == 9
              raise "Do not use AR on the main thread, use ActiveRecord::Base.connection_pool.with_connection"
            else
              sleep 0.5
            end
          end
        else
          # make sure we do not regress into slow startup time by preloading too much
          [
            ActiveRecord::Base.send(:descendants).map(&:name) - ["Audited::Audit"],
            ActionController::Base.descendants.map(&:name),
            (defined?(Mocha) && "mocha"),
            Thread.list.count == 1 || "Extra threads"
          ].compact.flatten.each { |c| raise "#{c} should not be loaded" }
        end
      end
    end
  end
end
