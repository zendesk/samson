# frozen_string_literal: true

class BumpResourceTemplateSize < ActiveRecord::Migration[5.2]
  def change
    change_column :kubernetes_release_docs, :resource_template, :text, limit: 16777215
  end
end
