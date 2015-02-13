class PluginManager
  include Singleton

  def initialize
    FileUtils.mkpath(extracted_plugins_dir)
    installed_plugins.each do |item|
      $:.unshift "#{extracted_plugins_dir}/#{item['name']}-#{item['version']}/lib"
      require "#{item['require']}"
    end
  end

  def installed_plugins
    YAML.load_file(Rails.root.join('plugins.yml'))['plugins']
  end

  def routes
    SamsonSdk::Plugins::WebPlugin.routes
  end

  def stage_config_plugins
    SamsonSdk::Plugins::stage_config_plugins
  end

  def extract_all_gems
    plugin_gems.each { |plugin_gem| unpack_gem(plugin_gem) unless extracted?(plugin_name(plugin_gem)) }
  end

  def plugin_gems
    Dir["#{plugins_dir}/*.gem"]
  end

  def plugin_name(plugin_gem)
    plugin_name = Pathname.new(plugin_gem).basename.to_s
    plugin_name[0, plugin_name.rindex('-')]
  end

  def plugins_dir
    Rails.root.join('plugins')
  end

  def extracted_plugins_dir
    Rails.root.join('tmp/plugins')
  end

  def extracted?(plugin_name)
    Dir.exist?(File.join(extracted_plugins_dir, plugin_name))
  end

  def unpack_gem(plugin_gem)
  end

end
