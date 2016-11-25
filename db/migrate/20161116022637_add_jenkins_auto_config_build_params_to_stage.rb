# frozen_string_literal: true
class AddJenkinsAutoConfigBuildParamsToStage < ActiveRecord::Migration[5.0]
  def change
    add_column :stages, :jenkins_build_params, :boolean, default: false, null: false
  end
end
