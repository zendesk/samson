module Samson
  module Hooks
    KNOWN = [
      :stage_form,
      :stage_clone,
      :stage_permitted_params,
      :before_deploy,
      :deploy_view,
      :after_deploy
    ]

    @@hooks = {}

    class Plugin
      def initialize(path)
        @path = path
        @folder = File.expand_path('../../../', @path)
        @name = File.basename(@folder)
      end

      def active?
        Rails.env.test? || ENV["PLUGINS"] == "all" || ENV["PLUGINS"].to_s.split(",").include?(@name)
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

      def add_decorators
        engine.config.after_initialize do
          Dir.glob(engine.config.root.join('app/decorators/**/*_decorator.rb')).each do |c|
            require_dependency(c)
          end
        end
      end

      def precompile_assets
        assets = javascripts + stylesheets
        engine.config.assets.precompile << assets
      end

      def javascripts
        assets(:javascripts, :js)
      end

      def stylesheets
        assets(:stylesheets, :scss, :css)
      end

      private

      def assets(type, *exts)
        basedir = assets_root(type)
        return [] if basedir.nil?
        find_assets(basedir, exts).map { |script| script.relative_path_from(Pathname.new(basedir)) }.map(&:to_s)
      end

      def find_assets(basedir, exts)
        exts.map do |ext|
          Dir.glob("#{basedir}/**/*.#{ext}").map { |asset| Pathname.new(asset) }
        end.flatten
      end

      def assets_root(type)
        engine.paths['app/assets'].existent.detect { |item| item.include?(type.to_s) }
      end

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
          each(&:add_lib_path).
          each(&:precompile_assets).
          each(&:add_decorators)
      end

      def render_javascripts(view)
        Samson::Hooks.plugins.map(&:javascripts).flatten.each do |script|
          view.instance_exec do
            concat view.javascript_include_tag(view.asset_path(script))
          end
        end
        nil
      end

      def render_stylesheets(view)
        Samson::Hooks.plugins.map(&:stylesheets).flatten.each do |stylesheet|
          view.instance_exec do
            concat view.stylesheet_link_tag(view.asset_path(stylesheet))
          end
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

Samson::Hooks.plugin_setup
ActionDispatch::Reloader.to_prepare { Samson::Hooks.plugin_setup }

