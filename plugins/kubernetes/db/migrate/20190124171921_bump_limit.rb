# frozen_string_literal: true

class BumpLimit < ActiveRecord::Migration[5.2]
  def change
    change_column :kubernetes_release_docs, :resource_template, :text, limit: 1073741823 # 1G, max size with 4 byte
  end
end
