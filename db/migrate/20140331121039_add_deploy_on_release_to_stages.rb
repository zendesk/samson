# frozen_string_literal: true
class AddDeployOnReleaseToStages < ActiveRecord::Migration[4.2]
  def change
    add_column :stages, :deploy_on_release, :boolean, default: false
  end
end
