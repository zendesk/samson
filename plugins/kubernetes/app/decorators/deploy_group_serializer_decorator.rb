# frozen_string_literal: true
DeployGroupSerializer.class_eval do
  has_one :kubernetes_cluster
end
