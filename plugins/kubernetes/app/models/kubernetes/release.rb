# frozen_string_literal: true
module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    belongs_to :user
    belongs_to :build
    belongs_to :project
    belongs_to :deploy
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id'
    has_many :deploy_groups, through: :release_docs

    validates :project, :git_sha, :git_ref, presence: true
    validate :validate_docker_image_in_registry, on: :create
    validate :validate_project_ids_are_in_sync

    def user
      super || NullUser.new(user_id)
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs
    def self.create_release(params)
      Kubernetes::Release.transaction do
        release = create(params.except(:deploy_groups))
        release.send :create_release_docs, params if release.persisted?
        release
      end
    end

    # optimization to not do multiple queries to the same cluster+namespace because we have many roles
    # ... needs to check doc namespace too since it might be not overwritten
    # ... assumes that there is only 1 namespace per release_doc
    def clients
      scopes = release_docs.map do |release_doc|
        [release_doc.deploy_group, release_doc.resources.first.namespace]
      end.uniq

      scopes.map do |group, namespace|
        query = {
          namespace: namespace,
          label_selector: pod_selector(group).map { |k, v| "#{k}=#{v}" }.join(",")
        }
        [group.kubernetes_cluster.client, query, group]
      end
    end

    def pod_selector(deploy_group)
      {
        release_id: id,
        deploy_group_id: deploy_group.id,
      }
    end

    def url
      Rails.application.routes.url_helpers.project_kubernetes_release_url(project, self)
    end

    private

    # Creates a ReleaseDoc per each DeployGroup and Role combination.
    def create_release_docs(params)
      params.fetch(:deploy_groups).each do |dg|
        dg.fetch(:roles).to_a.each do |role|
          release_docs.create!(
            deploy_group: dg.fetch(:deploy_group),
            kubernetes_role: role.fetch(:role),
            replica_target: role.fetch(:replicas),
            cpu: role.fetch(:cpu),
            ram: role.fetch(:ram)
          )
        end
      end
      raise Samson::Hooks::UserError, 'No roles or deploy groups given' if release_docs.empty?
    end

    def validate_docker_image_in_registry
      if build && !build.docker_repo_digest?
        errors.add(:build, 'Docker image was not pushed to registry')
      end
    end

    def validate_project_ids_are_in_sync
      if build && build.project_id != project_id
        errors.add(:build, 'build.project_id is out of sync with project_id')
      end
    end
  end
end
