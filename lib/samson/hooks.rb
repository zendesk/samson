module Samson
  module Hooks
    KNOWN = [
      :stage_defined,
      :stage_form,
      :stage_clone,
      :stage_permitted_params,
      :before_deploy,
      :after_deploy
    ]

    @@hooks = {}

    class << self
      # configure
      def callback(name, &block)
        hooks(name) << block
      end

      def view(name, partial)
        hooks(name) << partial
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

      private

      def hooks(name)
        raise "Using unsupported hook #{name.inspect}" unless KNOWN.include?(name)
        (@@hooks[name] ||= [])
      end
    end
  end
end


Dir["plugins/*/lib"].each { |f| $LOAD_PATH << f } # treat included plugins like gems

Gem.find_files("*/samson_plugin.rb").each do |plugin_path|
  require plugin_path
end
