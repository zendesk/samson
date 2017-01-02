# frozen_string_literal: true
class AddFlatToAllowBuildReuse < ActiveRecord::Migration[5.0]
  def change
    add_column :deploys, :kubernetes_reuse_build, :boolean, default: false, null: false
  end
end
