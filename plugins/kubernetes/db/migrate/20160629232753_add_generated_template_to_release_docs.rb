# frozen_string_literal: true
class AddGeneratedTemplateToReleaseDocs < ActiveRecord::Migration[4.2]
  def change
    add_column :kubernetes_release_docs, :resource_template, :text
  end
end
