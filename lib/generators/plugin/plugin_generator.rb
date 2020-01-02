# frozen_string_literal: true
require 'rails/generators'

# make zeitwerk happy
module Generators
  module Plugin
    module PluginGenerator
    end
  end
end

class PluginGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_plugin_file
    template 'samson_plugin.rb.erb', "plugins/#{file_name}/lib/samson_#{file_name}/samson_plugin.rb"
  end

  def create_gemspec_file
    template 'samson_plugin.gemspec.erb', "plugins/#{file_name}/samson_#{file_name}.gemspec"
  end

  def create_test_helper_file
    copy_file 'test_helper.rb.erb', "plugins/#{file_name}/test/test_helper.rb"
  end

  def create_directory_structure
    FileUtils.mkdir_p "#{destination_root}/plugins/#{file_name}/app/assets/javascript/"
    FileUtils.mkdir_p "#{destination_root}/plugins/#{file_name}/app/assets/stylesheets/"
    FileUtils.mkdir_p "#{destination_root}/plugins/#{file_name}/app/models/"
    FileUtils.mkdir_p "#{destination_root}/plugins/#{file_name}/app/views/samson_#{file_name}"
    FileUtils.mkdir_p "#{destination_root}/plugins/#{file_name}/db/migrate/"
  end

  def output_readme
    readme 'README'
  end

  private

  def username
    `git config user.name`.chomp.presence || '<insert your name here>'
  end

  def email
    `git config user.email`.chomp.presence || '<insert your email here>'
  end
end
