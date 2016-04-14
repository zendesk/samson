class SingleCov
  COVERAGES = []

  class << self
    def not_covered!
    end

    def covered!(file: nil, uncovered: 0)
      file ||= file_under_test(caller.first)
      raise "Need to use files relative to root" if file.start_with?("/")
      COVERAGES << [file, uncovered]
    end

    def verify!(result)
      errors = COVERAGES.map do |file, expected_uncovered|
        if coverage = result[File.expand_path(file)]
          uncovered_lines = coverage.each_with_index.map { |c, i| "#{file}:#{i+1}" if c == 0 }.compact
          next if uncovered_lines.size == expected_uncovered

          details = "#{uncovered_lines.size} current vs #{expected_uncovered} previous"
          if expected_uncovered > uncovered_lines.size
            "#{file} has less uncovered lines now #{details}, decrement expected uncovered?"
          else
            [
              "#{file} new uncovered lines introduced #{details}",
              "Lines missing coverage:",
              *uncovered_lines
            ].join("\n")
          end
        else
          uncovered_details(file)
        end
      end.compact

      if errors.any?
        warn errors
        exit 1 if errors.any? { |l| !l.end_with?('?') } # exit on error, but not on warning
      end
    end

    private

    def file_under_test(file)
      file = file.dup
      file.sub!("#{Rails.root}/", '')
      folder = (file =~ %r{(^|/)lib/} ? '' : 'app/')
      file.sub!(%r{(^|/)test/}, "\\1#{folder}")
      file.sub!(/_test.rb.*/, '.rb')
      file
    end

    def uncovered_details(file)
      if File.exist?(file)
        "#{file} was not covered during tests, possibly loaded before test start ?"
      else
        "#{file} does not exist and cannot be covered"
      end
    end
  end
end

# do not record or verify when only running selected tests since it would be missing data
unless ARGV.include?('-n')
  if defined?(SimpleCov)
    # - do not start again when SimpleCov is used / Coverage is already started or it conflicts
    # - do not ask for coverage when SimpleCov already does or it conflicts
    old = SimpleCov.at_exit
    SimpleCov.at_exit do
      old.call
      # SimpleCov.result returns a coverage that includes 0 instead of nil ... so use @result
      # https://github.com/colszowka/simplecov/pull/441
      result = SimpleCov.instance_variable_get(:@result).original_result
      SingleCov.verify! result
    end
  else
    # start recording before classes are loaded or nothing can be recorded
    require 'coverage'
    Coverage.start

    require 'minitest'
    Minitest.after_run do
      SingleCov.verify! Coverage.result
    end
  end
end
