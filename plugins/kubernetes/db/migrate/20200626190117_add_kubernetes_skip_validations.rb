# frozen_string_literal: true
class AddKubernetesSkipValidations < ActiveRecord::Migration[6.0]
  def change
    add_column :deploys, :kubernetes_skip_validations, :boolean, default: false, null: false
  end
end
