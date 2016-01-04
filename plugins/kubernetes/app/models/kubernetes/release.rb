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
        project: build.project_name
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
      Watchers::DeployWatcher.new(self)
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs and starts the deploy
    def self.create_release(params)
      Kubernetes::Release.transaction do
        release = create(params.except(:deploy_groups))
        if release.persisted?
          release.create_release_docs(params)

          # Starts rolling out the release into Kubernetes
          KuberDeployService.new(release).deploy!
        end
        release
      end
    end

    # Creates a ReleaseDoc per each DeployGroup and Role combination.
    def create_release_docs(params)
      params[:deploy_groups].to_a.each do |dg|
        dg[:roles].to_a.each do |role|
          release_docs.create!(deploy_group_id: dg[:id], kubernetes_role_id: role[:id], replica_target: role[:replicas])
        end
      end
      raise 'No Kubernetes::ReleaseDoc has been created' if release_docs.empty?
    end

    private

    def docker_image_in_registry?
      if build && build.docker_repo_digest.blank? && build.docker_ref.blank?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end
  end
end
