# frozen_string_literal: true
module Samson
  module Hooks
    class UserError < StandardError
    end

    VIEW_HOOKS = [
      :stage_form,
      :stage_show,
      :stage_form_checkbox,
      :project_form,
      :project_form_checkbox,
      :build_button,
      :build_new,
      :build_show,
      :deploy_changeset_tab_nav,
      :deploy_changeset_tab_body,
      :deploy_group_show,
      :deploy_group_form,
      :deploy_group_table_header,
      :deploy_group_table_cell,
      :deploys_header,
      :deploy_show_view,
      :deploy_view,
      :deploy_form, # for external plugin, so they can add extra form fields
      :admin_menu,
      :manage_menu,
      :project_dashboard,
      :project_tabs_view
    ].freeze

    EVENT_HOOKS = [
      :after_deploy,
      :after_deploy_setup,
      :after_docker_build,
      :before_deploy,
      :before_docker_build,
      :before_docker_repository_usage,
      :buddy_request,
      :build_permitted_params,
      :buildkite_release_params,
      :can,
      :deploy_group_includes,
      :deploy_group_permitted_params,
      :deploy_permitted_params,
      :error,
      :ignore_error,
      :deploy_env,
      :deploy_execution_env,
      :link_parts_for_resource,
      :project_docker_build_method_options,
      :project_permitted_params,
      :ref_status,
      :release_deploy_conditions,
      :resolve_docker_image_tag,
      :stage_clone,
      :stage_permitted_params,
      :trace_method,
      :trace_scope,
      :asynchronous_performance_tracer,
      :repo_provider_status,
      :repo_commit_from_ref,
      :repo_compare,
      :validate_deploy,
      :project_allowed_includes
    ].freeze

    # Hooks that are slow and we want performance info on
    TRACED = [
      :after_deploy,
      :after_deploy_setup,
      :after_docker_build,
      :before_deploy,
      :before_docker_build,
      :before_docker_repository_usage,
      :ref_status,
      :stage_clone
    ].freeze
    (TRACED & EVENT_HOOKS).sort == TRACED.sort || raise("Unknown hook in traced")

    KNOWN = VIEW_HOOKS + EVENT_HOOKS

    @hooks = Hash.new { |h, k| h[k] = [] }
    @class_decorators = Hash.new { |h, k| h[k] = [] }

    class Plugin
      attr_reader :name, :folder

      def initialize(path)
        @path = path
        @folder = File.expand_path('../../../', @path)
        @name = File.basename(@folder).sub(/-[^-]*\z/, '').sub(/\Asamson_/, "")
      end

      def setup_and_require
        lib = "#{@folder}/lib"
        $LOAD_PATH << lib
        require @path
        engine.config.eager_load_paths << lib
      end

      def add_migrations
        migrations = File.join(@folder, "db/migrate")
        Rails.application.config.paths["db/migrate"] << migrations if Dir.exist?(migrations)
      end

      def add_decorators
        Dir["#{decorators_root}/**/*_decorator.rb"].each do |path|
          Samson::Hooks.decorator(decorator_class(path), path)
        end
      end

      def engine
        @engine ||= Kernel.const_get("::Samson#{@name.camelize}::SamsonPlugin")
      end

      private

      def decorators_root
        @decorators_root ||= Pathname("#{@folder}/decorators")
      end

      # {root}/xyz_decorator.rb -> Xyz
      # {root}/xy/z_decorator.rb -> Xy::Z
      def decorator_class(path)
        relative_path = Pathname.new(path).relative_path_from(decorators_root).to_s
        relative_path.sub('_decorator.rb', '').split('/').map(&:classify).join('::')
      end
    end

    class << self
      def plugins
        @plugins ||= begin
          Gem.find_files("samson_*/samson_plugin.rb").
            map { |path| Plugin.new(path) }.
            select { |p| active_plugin?(p.name) }.
            sort_by(&:name)
        end
      end

      def active_plugin?(plugin_name)
        @plugin_list ||= ENV['PLUGINS'].to_s.split(',').map(&:strip).to_set
        (@plugin_list.include?(plugin_name) || @plugin_list.include?('all')) &&
          !@plugin_list.include?("-#{plugin_name}")
      end

      # configure
      def callback(name, &block)
        hooks(name) << block
      end

      def view(name, plugin)
        hooks(name) << (plugin.include?("/") ? plugin : "#{plugin}/#{name}")
      end

      def decorator(class_name, file)
        @class_decorators[class_name] << file
      end

      # temporarily add a hook for testing
      def with_callback(name, *hook_blocks)
        original_hooks = @hooks[name].dup
        @hooks[name] = hook_blocks
        yield
      ensure
        @hooks[name] = original_hooks
      end

      # temporarily removes all callbacks for specified hook except for those of the passed in plugin for testing
      def only_callbacks_for_plugin(plugin_name, hook_name)
        original_hooks = @hooks[hook_name]
        @hooks[hook_name] = @hooks[hook_name].select do |proc|
          proc.source_location.first.include?("/#{plugin_name}/")
        end
        yield
      ensure
        @hooks[hook_name] = original_hooks
      end

      # use
      def fire(name, *args, **kwargs)
        traced(name) { hooks(name).map { |hook| hook.call(*args, **kwargs) } }
      end

      def render_views(name, view, *args, **kwargs)
        hooks(name).each_with_object("".html_safe) do |partial, html|
          html << view.render(partial, *args, **kwargs)
        end
      end

      def load_decorators(klass)
        @class_decorators[klass.name].each { |path| load(path) }
      end

      def plugin_setup
        Samson::Hooks.plugins.
          each(&:setup_and_require).
          each(&:add_migrations).
          each(&:add_decorators)
      end

      def symlink_plugin_fixtures
        fixture_path = ActiveSupport::TestCase.fixture_path
        links = plugins.flat_map do |plugin|
          fixtures = Dir.glob(File.join(plugin.folder, 'test', 'fixtures', '*'))
          fixtures.map! { |fixture| [fixture, File.join(fixture_path, File.basename(fixture))] }
        end

        # avoid errors when running in parallel
        links.each { |from, to| File.symlink(from, to) rescue false } # rubocop:disable Style/RescueModifier

        if ENV['TEST_ENV_NUMBER'].to_s == '' # only run in first parallel test
          # rails test does not trigger after_run and rake does not work with at_exit
          # https://github.com/rails/rails/pull/26515
          callback = -> do
            links.each { |_, to| File.delete(to) rescue false } # rubocop:disable Style/RescueModifier
          end
          if Minitest.respond_to?(:run_with_rails_extension) && Minitest.run_with_rails_extension
            at_exit(&callback)
          else
            Minitest.after_run(&callback)
          end
        end
      end

      def render_javascripts(view)
        render_assets view, 'javascripts', 'application.js', :javascript_include_tag
      end

      def render_stylesheets(view)
        render_assets view, 'stylesheets', 'application.css', :stylesheet_link_tag
      end

      private

      def traced(name, &block)
        if TRACED.include?(name)
          Samson::PerformanceTracer.trace_execution_scoped("Custom/Hooks/#{name}", &block)
        else
          yield
        end
      end

      def render_assets(view, folder, file, method)
        Samson::Hooks.plugins.each do |plugin|
          full_file = plugin.engine.config.root.join("app/assets/#{folder}/#{plugin.name}/#{file}")
          next unless File.exist?(full_file)
          view.concat(view.send(method, "#{plugin.name}/#{file}"))
        end
        nil
      end

      def hooks(name)
        raise "Using unsupported hook #{name.inspect}" unless KNOWN.include?(name)
        @hooks[name]
      end
    end
  end
end

Samson::Hooks.plugin_setup
