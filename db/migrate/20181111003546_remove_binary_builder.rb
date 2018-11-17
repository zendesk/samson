# frozen_string_literal: true
class RemoveBinaryBuilder < ActiveRecord::Migration[5.2]
  class Stage < ActiveRecord::Base
  end

  def change
    # postgres cannot rescue aleter statements, so we need to be sure the up migration for this ran
    if Stage.column_names.include? 'docker_binary_plugin_enabled'
      remove_column :stages, :docker_binary_plugin_enabled
    end
  end
end
