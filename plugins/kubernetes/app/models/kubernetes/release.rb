module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    STATUSES = %w[created spinning_up live spinning_down dead]

    belongs_to :user
    belongs_to :build
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id'

    delegate :project, to: :build

    validates :build, presence: true
    validates :status, inclusion: STATUSES
    validate :docker_image_in_registry?, on: :create

    STATUSES.each do |s|
      define_method("#{s}?") { status == s }
    end

    def release_is_live!
      self.status = :live
      self.deploy_finished_at = Time.now
      save!
    end

    def pod_labels
      {
        project: build.project_name,
        release_id: id.to_s
      }
    end

    def user
      super || NullUser.new(user_id)
    end

    def nested_error_messages
      errors.full_messages + release_docs.flat_map(&:nested_error_messages)
    end

    def docs_by_role
      @docs_by_role ||= release_docs.each_with_object({}) do |rel_doc, hash|
        hash[rel_doc.kubernetes_role.label_name] = rel_doc
      end
    end

    def watch
      Watchers::DeployWatcher.new(self).async :watch
    end

    def deploy_group_ids
      release_docs.map(&:deploy_group_id)
    end

    def deploy_group_ids=(_id_list)
    end

    private

    def docker_image_in_registry?
      if build && build.docker_repo_digest.blank?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end
  end
end
