# frozen_string_literal: true
class SetKuberReleaseDefaultStatus < ActiveRecord::Migration[4.2]
  def change
    change_column :kubernetes_releases, :status, :string, default: 'created'
    change_column :kubernetes_release_docs, :status, :string, default: 'created'
  end
end
