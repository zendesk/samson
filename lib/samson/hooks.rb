module Samson
  module Hooks
    class UserError < StandardError
    end

    VIEW_HOOKS = [
      :stage_form,
      :project_form,
      :deploys_header,
      :deploy_view,
      :deploy_form, # for external plugin, so they can add extra form fields
      :admin_menu,
      :project_tabs_view
    ].freeze

    EVENT_HOOKS = [
      :stage_clone,
      :stage_permitted_params,
      :deploy_permitted_params, # for external plugin
      :project_permitted_params,
      :before_deploy,
      :after_deploy_setup,
      :after_deploy,
      :after_docker_build,
    ].freeze

    INTERNAL_HOOKS = [ :class_defined ]

    KNOWN = VIEW_HOOKS + EVENT_HOOKS + INTERNAL_HOOKS

    @@hooks = {}

    class Plugin
      attr_reader :name, :folder
      def initialize(path)
        @path = path
        @folder = File.expand_path('../../../', @path)
        @name = realname(File.basename(@folder))
      end

      def active?
        Rails.env.test? || ENV["PLUGINS"] == "all" || ENV["PLUGINS"].to_s.split(',').map(&:strip).include?(@name)
      end

      def load
        lib = "#{@folder}/lib"
        $LOAD_PATH << lib
        require @path
        engine.config.autoload_paths << lib
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
        engine.config.assets.precompile += %W(#{name}/application.css #{name}/application.js)
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
          Gem.find_files("*/samson_plugin.rb").map { |path| Plugin.new(path) }.select(&:active?)
        end
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
        hooks(name).map { |hook| hook.call(*args) }
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

      def plugin_test_setup
        fixture_path = ActiveSupport::TestCase.fixture_path
        plugins.each do |plugin|
          fixtures = Dir.glob(File.join(plugin.folder, 'test', 'fixtures', '*.yml'))
          fixtures.each do |fixture|
            yml_filename = fixture[/\w+\.yml\z/]
            new_path = File.join(fixture_path, yml_filename)
            File.symlink(fixture, new_path)
            Minitest.after_run { File.delete(new_path) }
          end
        end
      end

      def render_javascripts(view)
        Samson::Hooks.plugins.each do |plugin|
          next unless File.exists?(plugin.engine.config.root.join("app/assets/javascripts/#{plugin.name}/application.js"))
          view.concat(view.javascript_include_tag("#{plugin.name}/application.js"))
        end
        nil
      end

      def render_stylesheets(view)
        Samson::Hooks.plugins.each do |plugin|
          next unless File.exists?(plugin.engine.config.root.join("app/assets/stylesheets/#{plugin.name}/application.css"))
          view.concat(view.stylesheet_link_tag("#{plugin.name}/application.css"))
        end
        nil
      end

      private

      def hooks(*args)
        raise "Using unsupported hook #{args.inspect}" unless KNOWN.include?(args.first)
        (@@hooks[args] ||= [])
      end
    end
  end
end

module Samson::LoadDecorators
  def inherited(subclass)
    Samson::Hooks.load_decorators(subclass.name)
    super
  end
end

Samson::Hooks.plugin_setup
ActiveRecord::Base.extend Samson::LoadDecorators
ActionController::Base.extend Samson::LoadDecorators
