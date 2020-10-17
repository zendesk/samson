# frozen_string_literal: true

module Samson
  module ProcessUtils
    ATTRIBUTES = ['pid', 'ppid', 'gid', 'pcpu', 'user', 'start', 'args'].freeze

    class << self
      def ps_list
        whitelists = ENV.fetch('PROCESS_WHITELIST', '').split(',')
        IO.popen("ps -eo #{ATTRIBUTES.join(',')}") do |pipe|
          # Ignore known long-running processes so report is meaningful
          filtered_processes = pipe.readlines[1..].reject do |lines|
            whitelists.any? { |key| lines.include?(key) }
          end
          filtered_processes.map do |line|
            Hash[ATTRIBUTES.zip line.lstrip.split(/\s+/, ATTRIBUTES.size)]
          end
        end
      end

      def report_to_statsd
        ps_list.each do |process|
          runtime =
            begin
              Time.now.to_i - Time.parse(process.fetch('start')).to_i
            rescue ArgumentError
              0
            end
          tags = ATTRIBUTES.map { |attr| "#{attr}:#{process.fetch(attr)}" }
          Samson.statsd.gauge("process.runtime", runtime, tags: tags)
        end
      end
    end
  end
end
