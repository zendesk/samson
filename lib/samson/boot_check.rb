# frozen_string_literal: true
module Samson
  module BootCheck
    class << self
      def check
        if ENV['SERVER_MODE'] || ENV['PROFILE']
          # make sure nobody uses connections on the main thread since they will block reloading in dev
          error = "Do not use AR on the main thread, use ActiveRecord::Base.connection_pool.with_connection"
          Samson::Retry.until_result tries: 10, wait_time: 0.5, error: error do
            ActiveRecord::Base.connection_pool.stat.fetch(:busy) == 0
          end
        else
          extra_threads = (Thread.list - [Thread.current]).reject do |t|
            t.backtrace(1).first.match?(/ruby_thread_local_var/) # threads get started by loading logger - ignore them
          end

          # make sure we do not regress into slow startup time by preloading too much
          bad = [
            ActiveRecord::Base.descendants.map(&:name) - ["Audited::Audit"],
            ActionController::Base.descendants.map(&:name) - ["RollbarTestController"],
            (const_defined?(:Mocha) && "mocha"),
            (extra_threads.any? && "Extra threads: #{extra_threads}")
          ].flatten.select { |x| x }
          raise "#{bad.join(", ")} should not be loaded" if bad.any?
        end
      end
    end
  end
end
