class PluginManager
  include Singleton

  def initialize
    FileUtils.mkpath(extracted_plugins_dir)
    load_plugins
  end

  def load_plugins
    installed_plugins.each do |plugin_details|
      $:.unshift(plugin_lib_dir(plugin_details))
      require "#{plugin_details['require']}"
      load_assets_paths(plugin_details)
    end
  end

  def load_assets_paths(plugin_details)
    Rails.application.config.assets.paths << "#{plugin_assets_path(plugin_details)}/js"
    Rails.application.config.assets.paths << "#{plugin_assets_path(plugin_details)}/stylesheets"
    Rails.application.config.assets.paths << "#{plugin_assets_path(plugin_details)}/css"
    Rails.application.config.assets.paths << "#{plugin_assets_path(plugin_details)}/images"
  end

  def plugin_lib_dir(plugin_details)
    "#{extracted_plugins_dir}/#{plugin_details['name']}-#{plugin_details['version']}/lib"
  end

  def installed_plugins
    YAML.load_file(Rails.root.join('plugins.yml'))['plugins']
  end

  def plugin_path(plugin_details)
    Rails.root.join('tmp', 'plugins', "#{plugin_details['name']}-#{plugin_details['version']}").to_s
  end

  def plugin_assets_path(plugin_details)
    File.join(plugin_path(plugin_details), 'assets')
  end

  def plugin_views_path(plugin_details)
    File.join(plugin_path(plugin_details), 'views')
  end

  def routes
    SamsonSdk::Plugins::WebPlugin.routes
  end

  def stage_config_plugins
    SamsonSdk::Plugins::stage_config_plugins
  end

  def javascript_assets
    SamsonSdk::Plugins::WebPlugin.all.map { |plugin| plugin.javascript_assets }.flatten
  end


  def stylesheets_assets
    SamsonSdk::Plugins::WebPlugin.all.map{ |plugin| plugin.stylesheet_assets }.flatten
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

end
