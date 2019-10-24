# frozen_string_literal: true
class AddIstioInjectColumn < ActiveRecord::Migration[5.2]
  def change
    add_column :kubernetes_deploy_group_roles, :inject_istio_annotation, :boolean, default: false, null: false
  end
end
