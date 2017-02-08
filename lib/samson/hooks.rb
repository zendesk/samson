# frozen_string_literal: true
module Samson
  module Hooks
    class UserError < StandardError
    end

    VIEW_HOOKS = [
      :stage_form,
      :stage_show,
      :project_form,
      :build_new,
      :deploy_group_show,
      :deploy_group_form,
      :deploy_group_table_header,
      :deploy_group_table_cell,
      :deploys_header,
      :deploy_tab_nav,
      :deploy_tab_body,
      :deploy_view,
      :deploy_form, # for external plugin, so they can add extra form fields
      :admin_menu,
      :project_tabs_view
    ].freeze

    EVENT_HOOKS = [
      :stage_clone,
      :stage_permitted_params,
      :deploy_permitted_params,
      :project_permitted_params,
      :deploy_group_permitted_params,
      :build_permitted_params,
      :before_deploy,
      :after_deploy_setup,
      :after_deploy,
      :before_docker_repository_usage,
      :before_docker_build,
      :after_docker_build,
      :after_job_execution,
      :job_additional_vars,
      :buildkite_release_params,
      :release_deploy_conditions,
      :deploy_group_env
    ].freeze

    INTERNAL_HOOKS = [:class_defined].freeze

    KNOWN = VIEW_HOOKS + EVENT_HOOKS + INTERNAL_HOOKS

    @hooks = {}

    class Plugin
      attr_reader :name, :folder
      def initialize(path)
        @path = path
        @folder = File.expand_path('../../../', @path)
        @name = realname(File.basename(@folder))
      end

      def load
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
        Dir[decorators_root.join('**/*_decorator.rb')].each do |path|
          Samson::Hooks.decorator(decorator_class(path), path)
        end
      end

      def add_assets_to_precompile
        engine.config.assets.precompile += %W[#{name}/application.css #{name}/application.js]
      end

      def engine
        @engine ||= Kernel.const_get("::Samson#{@name.camelize}::Engine")
      end

      private

      def realname(gemname)
        gemname.sub(/-[^-]*\z/, '').sub(/\Asamson_/, "")
      end

      def decorators_root
        @decorators_root ||= engine.config.root.join("app/decorators")
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
          Gem.find_files("*/samson_plugin.rb").map { |path| Plugin.new(path) }.select { |p| active_plugin?(p.name) }
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

      def view(name, partial)
        hooks(name) << partial
      end

      def decorator(class_name, file)
        hooks(:class_defined, class_name) << file
      end

      # temporarily add a hook for testing
      def with_callback(name, hook_block)
        hooks(name) << hook_block
        yield
      ensure
        hooks(name).pop
      end

      # use
      def fire(name, *args)
        NewRelic::Agent::MethodTracerHelpers.trace_execution_scoped("Custom/Hooks/#{name}") do
          hooks(name).map { |hook| hook.call(*args) }
        end
      end

      def render_views(name, view, *args)
        hooks(name).each_with_object("".html_safe) do |partial, html|
          html << view.render(partial, *args)
        end
      end

      def load_decorators(class_name)
        hooks(:class_defined, class_name).each { |path| require_dependency(path) }
      end

      def plugin_setup
        Samson::Hooks.plugins.
          each(&:load).
          each(&:add_migrations).
          each(&:add_assets_to_precompile).
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
            links.each { |_from, to| File.delete(to) rescue false } # rubocop:disable Style/RescueModifier
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

      def render_assets(view, folder, file, method)
        Samson::Hooks.plugins.each do |plugin|
          full_file = plugin.engine.config.root.join("app/assets/#{folder}/#{plugin.name}/#{file}")
          next unless File.exist?(full_file)
          view.concat(view.send(method, "#{plugin.name}/#{file}"))
        end
        nil
      end

      def hooks(*args)
        raise "Using unsupported hook #{args.inspect}" unless KNOWN.include?(args.first)
        (@hooks[args] ||= [])
      end
    end
  end
end

module Samson::LoadDecorators
  def inherited(subclass)
    super
    Samson::Hooks.load_decorators(subclass.name)
  end
end

Samson::Hooks.plugin_setup

class << ActiveRecord::Base
  prepend Samson::LoadDecorators
end
class << ActionController::Base
  prepend Samson::LoadDecorators
end
class << ActiveModel::Serializer
  prepend Samson::LoadDecorators
end
