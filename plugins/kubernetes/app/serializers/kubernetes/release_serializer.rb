module Kubernetes
  class ReleaseSerializer < ActiveModel::Serializer
    include DateTimeHelper

    attributes :id, :created_at

    has_one :user
    has_one :build
    has_many :deploy_groups

    def created_at
      datetime_to_js_ms(object.created_at)
    end

    def deploy_groups
      object.release_docs.map(&:deploy_group).uniq
    end
  end
end
