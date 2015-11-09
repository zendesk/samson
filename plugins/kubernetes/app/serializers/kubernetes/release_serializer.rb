module Kubernetes
  class ReleaseSerializer < ActiveModel::Serializer
    attributes :id, :created_at

    has_one :deploy_group
  end
end
