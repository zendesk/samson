# frozen_string_literal: true
class RemoveDeployBuildId < ActiveRecord::Migration[5.2]
  def change
    remove_column :deploys, :build_id
  end
end
