# frozen_string_literal: true
module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    belongs_to :user
    belongs_to :project
    belongs_to :deploy
    has_many :release_docs, class_name: 'Kubernetes::ReleaseDoc', foreign_key: 'kubernetes_release_id'
    has_many :deploy_groups, through: :release_docs

    validates :project, :git_sha, :git_ref, presence: true

    def user
      super || NullUser.new(user_id)
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs
    def self.create_release(params)
      Kubernetes::Release.transaction do
        release = create(params.except(:deploy_groups)) do |release|
          if params.fetch(:deploy_groups).any? { |dg| dg.fetch(:roles).any? { |role| role.fetch(:role).blue_green? } }
            release.blue_green_color = begin
              release.previous_successful_release&.blue_green_color == "blue" ? "green" : "blue"
            end
          end
        end
        release.send :create_release_docs, params if release.persisted?
        release
      end
    end

    # simple method to tie all selector logic together
    def self.pod_selector(release_id, deploy_group_id, query:)
      selector = {
        release_id: release_id,
        deploy_group_id: deploy_group_id,
      }
      query ? selector.map { |k, v| "#{k}=#{v}" }.join(",") : selector
    end

    # optimization to not do multiple queries to the same cluster+namespace because we have many roles
    # ... needs to check doc namespace too since it might be not overwritten
    # ... assumes that there is only 1 namespace per release_doc
    # ... supports that the same namespace might exist on different clusters
    def clients
      scopes = release_docs.map do |release_doc|
        release_id = resource_release_id(release_doc)
        [
          release_doc.deploy_group,
          {
            namespace: release_doc.resources.first.namespace,
            label_selector: self.class.pod_selector(release_id, release_doc.deploy_group.id, query: true)
          }
        ]
      end
      # avoiding doing a .uniq on clients which might do weird stuff
      scopes.uniq.map { |group, query| [group.kubernetes_cluster.client, query] }
    end

    def url
      Rails.application.routes.url_helpers.project_kubernetes_release_url(project, self)
    end

    def builds
      Build.where(git_sha: git_sha)
    end

    def previous_successful_release
      deploy.previous_successful_deploy&.kubernetes_release
    end

    private

    # StatefulSet does not update the labels when using patch_replace, so find by old label
    def resource_release_id(release_doc)
      stateful_set = release_doc.resources.detect do |r|
        r.is_a?(Kubernetes::Resource::StatefulSet) && r.patch_replace?
      end
      return id unless stateful_set

      stateful_set.resource.dig(:spec, :template, :metadata, :labels, :release_id) ||
        raise(KeyError, "Unable to find previous release_id")
    end

    # Creates a ReleaseDoc per each DeployGroup and Role combination.
    def create_release_docs(params)
      params.fetch(:deploy_groups).each do |dg|
        dg.fetch(:roles).to_a.each do |role|
          release_docs.create!(
            deploy_group: dg.fetch(:deploy_group),
            kubernetes_role: role.fetch(:role),
            replica_target: role.fetch(:replicas),
            requests_cpu: role.fetch(:requests_cpu),
            requests_memory: role.fetch(:requests_memory),
            limits_cpu: role.fetch(:limits_cpu),
            limits_memory: role.fetch(:limits_memory),
            delete_resource: role.fetch(:delete_resource)
          )
        end
      end
      raise Samson::Hooks::UserError, 'No roles or deploy groups given' if release_docs.empty?
    end
  end
end
