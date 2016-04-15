class SingleCov
  COVERAGES = []
  MAX_OUTPUT = 40

  class << self
    def not_covered!
    end

    def covered!(file: nil, uncovered: 0)
      file = guess_and_check_covered_file(file)
      COVERAGES << [file, uncovered]
    end

    def verify!(result)
      errors = COVERAGES.map do |file, expected_uncovered|
        if coverage = result[File.expand_path(file)]
          uncovered_lines = coverage.each_with_index.map { |c, i| "#{file}:#{i+1}" if c == 0 }.compact
          next if uncovered_lines.size == expected_uncovered
          warn_about_bad_coverage(file, expected_uncovered, uncovered_lines)
        else
          warn_about_no_coverage(file)
        end
      end.compact

      if errors.any?
        errors = errors.join("\n").split("\n") # unify arrays with multiline strings
        errors[MAX_OUTPUT..-1] = "... coverage output truncated" if errors.size >= MAX_OUTPUT
        warn errors
        exit 1 if errors.any? { |l| !l.end_with?('?') } # exit on error, but not on warning
      end
    end

    # not running rake or a whole folder
    # TODO make this better ...
    def running_single_file?
      !defined?(Rake)
    end

    private

    def guess_and_check_covered_file(file)
      if file && file.start_with?("/")
        raise "Use paths relative to rails root."
      end

      if file
        raise "#{file} does not exist and cannot be covered." unless File.exist?(file)
      else
        file = file_under_test(caller[1])
        unless File.exist?(file)
          raise "Tried to guess covered file as #{file}, but it does not exist.\nUse `file:` argument to set covered file location."
        end
      end

      file
    end

    def warn_about_bad_coverage(file, expected_uncovered, uncovered_lines)
      details = "#{uncovered_lines.size} current vs #{expected_uncovered} previous"
      if expected_uncovered > uncovered_lines.size
        if running_single_file?
          "#{file} has less uncovered lines now #{details}, decrement expected uncovered?"
        end
      else
        [
          "#{file} new uncovered lines introduced #{details}",
          "Lines missing coverage:",
          *uncovered_lines
        ].join("\n")
      end
    end

    def warn_about_no_coverage(file)
      if $LOADED_FEATURES.include?(File.expand_path(file))
        # we cannot enforce $LOADED_FEATURES during covered! since it would fail when multiple files are loaded
        "#{file} was expected to be covered, but already loaded before tests started."
      else
        "#{file} was expected to be covered, but never loaded."
      end
    end

    def file_under_test(file)
      file = file.dup
      file.sub!("#{Rails.root}/", '')
      folder = (file =~ %r{(^|/)lib/} ? '' : 'app/')
      file.sub!(%r{(^|/)test/}, "\\1#{folder}")
      file.sub!(/_test.rb.*/, '.rb')
      file
    end
  end
end

# do not record or verify when only running selected tests since it would be missing data
if (ARGV & ['-n', '--name', '-l', '--line']).empty?
  if defined?(SimpleCov)
    # - do not start again when SimpleCov is used / Coverage is already started or it conflicts
    # - do not ask for coverage when SimpleCov already does or it conflicts
    # - TODO: do not spam on Interrupts https://github.com/colszowka/simplecov/issues/493
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
    # TODO: do not show coverage when user interrupts ... but after_run does not give us that info
    # https://github.com/seattlerb/minitest/issues/618
    require 'coverage'
    Coverage.start

    require 'minitest'
    Minitest.after_run do
      SingleCov.verify! Coverage.result
    end
  end
end
