# frozen_string_literal: true
class AddEnableDockerBinaryBuilderToStage < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :docker_binary_plugin_enabled, :boolean, default: true
  end
end
