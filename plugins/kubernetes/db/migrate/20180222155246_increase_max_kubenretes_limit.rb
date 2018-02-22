# frozen_string_literal: true
class IncreaseMaxKubenretesLimit < ActiveRecord::Migration[5.1]
  def change
    [
      [:kubernetes_usage_limits, :cpu],
      [:kubernetes_deploy_group_roles, :limits_cpu],
      [:kubernetes_deploy_group_roles, :requests_cpu],
      [:kubernetes_release_docs, :limits_cpu],
      [:kubernetes_release_docs, :requests_cpu],
    ].each do |table, column|
      change_column table, column, :decimal, precision: 6, scale: 2, null: false
    end
  end
end
