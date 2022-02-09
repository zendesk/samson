# frozen_string_literal: true
module Samson
  module ConsoleExtensions
    # used to fake a login while debugging in a `rails c` console session
    # so app.get 'http://xyz.com/protected/resource' works
    def login(user)
      CurrentUser.class_eval do
        define_method(:current_user) { user }
        define_method(:login_user) {}
        define_method(:verify_authenticity_token) {}
      end
      "logged in as #{user.name}"
    end

    # resets all caching in the controller and Rails.cache.fetch so we get worst-case performance
    # restart console to re-enable
    def use_clean_cache
      ActionController::Base.config.cache_store = Rails.cache = ActiveSupport::Cache::MemoryStore.new
    end

    # produce a flamegraph and print instructions to opening it
    # dumps into a static location so users can refresh in their browsers to update
    # default `:interval` sample every interval microseconds (default: 1000), use 100 or 10 for fast things
    def flamegraph(name: 'test', **options, &block)
      raise "Use PROFILE mode or set config.cache_classes = true" unless Rails.application.config.cache_classes
      raise "Use PROFILE mode or set Rails.logger.level = 1" unless Rails.logger.level == 1

      require 'stackprof' # here because gem is not available in prod where we autoload

      options[:raw] = true
      options[:mode] ||= :wall

      time_taken = nil
      GC.disable
      dump = ActiveSupport::Deprecation.silence do
        StackProf.run(**options) do
          time_taken = Benchmark.realtime(&block)
        end
      end
      GC.enable

      report = StackProf::Report.new(dump)
      file = "#{name}.js"
      File.open(file, 'w+') { |f| report.print_flamegraph(f) }

      spec = Gem::Specification.find_by_name("stackprof")
      path = File.expand_path(file)
      puts "open in your browser: file://#{spec.gem_dir}/lib/stackprof/flamegraph/viewer.html?data=#{path}"

      time_taken
    end
  end
end
