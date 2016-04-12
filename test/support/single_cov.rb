class SingleCov
  COVERAGES = []

  class << self
    def covered!(file: nil, percent: 100)
      unless file
        file = caller.first[%r{/test/(.*?)_test\.rb}, 1] << '.rb'
        file[0...0] = 'app/' unless file.start_with?('lib/')
      end

      COVERAGES << [file, percent]
    end

    def verify!(result)
      COVERAGES.each do |file, expected_percent|
        uncovered!(file) unless coverage = result[File.expand_path(file)]

        line_of_code = coverage.compact.count
        line_of_covered_code = coverage.count { |l| l && l > 0 }
        actual_percent = 100 * line_of_covered_code / line_of_code
        next if actual_percent == expected_percent

        details = "#{actual_percent}% vs #{expected_percent}%"
        if actual_percent > expected_percent
          warn "#{file} exceeds expected coverage #{details}, increment expected coverage?"
        else
          warn "#{file} lower then expected coverage #{details}"
          warn "Lines missing coverage:"
          warn coverage.each_with_index.map { |c, i| "#{file}:#{i+1}" if c == 0 }.compact
          exit 1
        end
      end
    end

    private

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
