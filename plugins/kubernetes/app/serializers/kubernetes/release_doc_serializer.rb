module Kubernetes
  class ReleaseDocSerializer < ActiveModel::Serializer
    include DateTimeHelper

    attributes :id, :created_at

    has_one :release
    has_one :deploy_group

    def created_at
      datetime_to_js_ms(object.created_at)
    end

    def deploy_groups
      object.release_docs.map(&:deploy_group)
    end
  end
end
