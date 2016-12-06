# frozen_string_literal: true
namespace :kubernetes do
  desc "Delete NotReady/dead kubernetes nodes that were left behind because their hosts died"
  task delete_dead_nodes: :environment do
    Kubernetes::Cluster.delete_dead_nodes
  end
end
