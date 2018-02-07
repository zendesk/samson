# frozen_string_literal: true
class AddAllowWritingToRootFilesystem < ActiveRecord::Migration[5.1]
  def change
    add_column :projects, :kubernetes_allow_writing_to_root_filesystem, :boolean, default: false, null: false
  end
end
