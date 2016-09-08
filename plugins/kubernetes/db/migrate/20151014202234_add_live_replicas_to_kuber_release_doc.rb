# frozen_string_literal: true
class AddLiveReplicasToKuberReleaseDoc < ActiveRecord::Migration[4.2]
  def change
    change_table :kubernetes_release_docs do |t|
      t.rename :replica_count, :replica_target
      t.integer :replicas_live, after: :replica_target, null: false, default: 0
    end
  end
end
