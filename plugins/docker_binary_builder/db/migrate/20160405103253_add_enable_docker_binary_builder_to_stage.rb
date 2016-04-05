class AddEnableDockerBinaryBuilderToStage < ActiveRecord::Migration
  def change
    add_column :stages, :docker_binary_plugin_enabled, :boolean, default: true
  end
end
