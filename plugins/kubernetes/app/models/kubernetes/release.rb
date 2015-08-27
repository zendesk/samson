module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    VALID_STATUSES = %w[created spinning_up live spinning_down dead]

    belongs_to :user
    belongs_to :build
    belongs_to :deploy_group
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc'

    validates :build, presence: true
    validates :deploy_group, presence: true
    validates :status, inclusion: VALID_STATUSES

    before_create :set_default_status

    def namespace
      deploy_group.namespace
    end

    # Need to define this method so that the "new" page is displayed properly
    # TODO: remove this hack.
    def deploy_group_ids
      [deploy_group.try(:id)]
    end

    # TODO: define state machine for 'status' field

    private

    def set_default_status
      self.status ||= 'created'
    end
  end
end
