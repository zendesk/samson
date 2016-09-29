# frozen_string_literal: true
class DisableBinaryByDefault < ActiveRecord::Migration[5.0]
  class Stage < ActiveRecord::Base
  end

  def change
    change_column_default :stages, :docker_binary_plugin_enabled, false
    change_column_null :stages, :docker_binary_plugin_enabled, false, false
  end
end
