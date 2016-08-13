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

    def clients
      release_docs.map(&:deploy_group).uniq.map do |deploy_group|
        query = {
          namespace: deploy_group.kubernetes_namespace,
          label_selector: pod_selector(deploy_group).to_kuber_selector
        }
        [deploy_group.kubernetes_cluster.client, query, deploy_group]
      end
    end

    def pod_selector(deploy_group)
      {
        release_id: id,
        deploy_group_id: deploy_group.id,
      }
    end

    private

    # Creates a ReleaseDoc per each DeployGroup and Role combination.
    def create_release_docs(params)
      params.fetch(:deploy_groups).each do |dg|
        dg.fetch(:roles).to_a.each do |role|
          release_docs.create!(
            deploy_group_id: dg.fetch(:id),
            kubernetes_role_id: role.fetch(:id),
            replica_target: role.fetch(:replicas),
            cpu: role.fetch(:cpu),
            ram: role.fetch(:ram)
          )
        end
      end
      raise ArgumentError, 'No roles or deploy groups given' if release_docs.empty?
    end

    def validate_docker_image_in_registry
      if build && build.docker_repo_digest.blank? && build.docker_ref.blank?
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
