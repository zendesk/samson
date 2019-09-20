# frozen_string_literal: true
class AddKubernetesIgnoreVulnerabilitiesToDeploys < ActiveRecord::Migration[5.2]
  def change
    add_column :deploys, :kubernetes_ignore_kritis_vulnerabilities, :boolean, default: false, null: false
  end
end
