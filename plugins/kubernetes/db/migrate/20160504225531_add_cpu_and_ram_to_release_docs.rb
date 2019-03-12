# frozen_string_literal: true
class AddCpuAndRamToReleaseDocs < ActiveRecord::Migration[4.2]
  class KubernetesReleaseDoc < ActiveRecord::Base
    belongs_to :kubernetes_role
  end

  class KubernetesRole < ActiveRecord::Base
  end

  def up
    add_column :kubernetes_release_docs, :cpu, :decimal, precision: 4, scale: 2
    add_column :kubernetes_release_docs, :ram, :integer

    KubernetesReleaseDoc.find_each do |doc|
      doc.cpu = doc.kubernetes_role&.cpu || 1
      doc.ram = doc.kubernetes_role&.ram || 1
      doc.save!
    end

    change_column_null :kubernetes_release_docs, :cpu, false
    change_column_null :kubernetes_release_docs, :ram, false
  end

  def down
    remove_column :kubernetes_release_docs, :cpu
    remove_column :kubernetes_release_docs, :ram
  end
end
