module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    VALID_STATUSES = %w[created spinning_up live spinning_down dead]

    belongs_to :release_group, class_name: 'Kubernetes::ReleaseGroup', foreign_key: 'kubernetes_release_group_id', inverse_of: :releases
    belongs_to :deploy_group
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id', inverse_of: :kubernetes_release

    validates :release_group, presence: true
    validates :deploy_group, presence: true
    validates :status, inclusion: VALID_STATUSES

    after_initialize :set_default_status, on: :create

    def namespace
      deploy_group.namespace
    end

    # TODO: define state machine for 'status' field

    def nested_error_messages
      errors.full_messages + release_groups.map(&:nested_error_messages).flatten
    end

    private

    def set_default_status
      self.status ||= 'created'
    end
  end
end
