class AddLiveReplicasToKuberReleaseDoc < ActiveRecord::Migration
  def change
    change_table :kubernetes_release_docs do |t|
      t.rename :replica_count, :replica_target
      t.integer :replicas_live, after: :replica_target, null: false, default: 0
    end
  end
end
