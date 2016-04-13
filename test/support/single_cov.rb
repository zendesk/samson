class SingleCov
  COVERAGES = []

  class << self
    def covered!(file: nil, uncovered: 0)
      file ||= file_under_test(caller.first)
      COVERAGES << [file, uncovered]
    end

    def verify!(result)
      COVERAGES.each do |file, expected_uncovered|
        uncovered!(file) unless coverage = result[File.expand_path(file)]

        uncovered_lines = coverage.each_with_index.map { |c, i| "#{file}:#{i+1}" if c == 0 }.compact
        next if uncovered_lines.size == expected_uncovered

        details = "#{uncovered_lines.size} current vs #{expected_uncovered} previous"
        if expected_uncovered > uncovered_lines.size
          warn "#{file} has more less uncovered lines now #{details}, decrement expected uncovered?"
        else
          warn "#{file} new uncovered lines introduced #{details}"
          warn "Lines missing coverage:"
          warn uncovered_lines
          exit 1
        end
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

    def uncovered!(file)
      message = if File.exist?(file)
        "#{file} was not covered during tests, possibly loaded before test start ?"
      else
        "#{file} does not exist and cannot be covered"
      end
      warn message
      exit 1
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
