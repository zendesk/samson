# frozen_string_literal: true
class RemoveBinaryBuilder < ActiveRecord::Migration[5.2]
  def change
    remove_column :stages, :docker_binary_plugin_enabled
  rescue StandardError # rubocop:disable Lint/HandleExceptions
    # user might have never installed the plugin
  end
end
