# frozen_string_literal: true
class AddGeneratedTemplateToReleaseDocs < ActiveRecord::Migration
  def change
    add_column :kubernetes_release_docs, :resource_template, :text
  end
end
