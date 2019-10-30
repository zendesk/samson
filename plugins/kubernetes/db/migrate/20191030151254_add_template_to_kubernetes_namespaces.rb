# frozen_string_literal: true
class AddTemplateToKubernetesNamespaces < ActiveRecord::Migration[5.2]
  def change
    add_column :kubernetes_namespaces, :template, :text
  end
end
