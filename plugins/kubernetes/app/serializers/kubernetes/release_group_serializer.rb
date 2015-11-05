module Kubernetes
  class ReleaseGroupSerializer < ActiveModel::Serializer
    include DateTimeHelper

    attributes :id, :created_at

    has_one :user
    has_one :build
    has_many :deploy_groups

    def deploy_groups
      object.releases.map { |release| release.deploy_group}
    end

    def created_at
      datetime_to_js_ms(object.created_at)
    end

  end
end


