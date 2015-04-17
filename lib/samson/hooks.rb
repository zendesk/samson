module Samson
  module Hooks
    KNOWN = [
      :model_defined,
      :stage_form,
      :stage_clone,
      :stage_permitted_params,
      :before_deploy,
      :deploy_view,
      :after_deploy
    ]

    @@hooks = {}

    class Plugin
      attr_reader :name
      def initialize(path)
        @path = path
        @folder = File.expand_path('../../../', @path)
        @name = File.basename(@folder)
      end

      def active?
        Rails.env.test? || ENV["PLUGINS"] == "all" || ENV["PLUGINS"].to_s.split(',').map(&:strip).include?(@name)
      end

      def require
        super @path
      end

      def add_migrations
        migrations = File.join(@folder, "db/migrate")
        Rails.application.config.paths["db/migrate"] << migrations if Dir.exist?(migrations)
      end

      def add_lib_path
        engine.config.autoload_paths += Dir["#{engine.config.root}/lib/**/"]
      end

      def add_decorator(klass_name)
        return if klass_name.nil?
        decorator_file = engine.config.root.join("app/decorators/#{klass_name.downcase}_decorator.rb")
        require_dependency(decorator_file) if File.exists?(decorator_file)
      end

      def add_assets_to_precompile
        engine.config.assets.precompile += %W(#{name}/application.css #{name}/application.js)
      end

      private

      def engine
        @engine ||= Kernel.const_get("::Samson#{@name.capitalize}::Engine")
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
        hooks(name).each do |partial|
          view.instance_exec { concat render(partial, *args) }
        end
        nil
      end

      def plugin_setup
        Samson::Hooks.plugins.
          each(&:require).
          each(&:add_migrations).
          each(&:add_assets_to_precompile).
          each(&:add_lib_path)
      end

      def render_javascripts(view)
        Samson::Hooks.plugins.each do |plugin|
          view.concat(view.javascript_include_tag("#{plugin.name}/application.js"))
        end
        nil
      end

      def render_stylesheets(view)
        Samson::Hooks.plugins.each do |plugin|
          view.concat(view.stylesheet_link_tag("#{plugin.name}/application.css"))
        end
        nil
      end

      private

      def hooks(name)
        raise "Using unsupported hook #{name.inspect}" unless KNOWN.include?(name)
        (@@hooks[name] ||= [])
      end
    end
  end
end

Dir["plugins/*/lib"].each { |f| $LOAD_PATH << f } # treat included plugins like gems

module LoadDecorators
  def inherited(subclass)
    Samson::Hooks.fire(:model_defined, subclass)
    super
  end
end

Samson::Hooks.callback :model_defined do |model_class|
  Samson::Hooks.plugins.each { |plugin| plugin.add_decorator(model_class.name) }
end

ActiveRecord::Base.extend LoadDecorators
Samson::Hooks.plugin_setup
