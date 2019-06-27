# frozen_string_literal: true
module Kubernetes
  class Release < ActiveRecord::Base
    self.table_name = 'kubernetes_releases'

    belongs_to :user, inverse_of: nil
    belongs_to :project, inverse_of: :kubernetes_releases
    belongs_to :deploy, inverse_of: :kubernetes_release
    has_many :release_docs,
      class_name: 'Kubernetes::ReleaseDoc',
      foreign_key: 'kubernetes_release_id',
      dependent: :destroy,
      inverse_of: :kubernetes_release
    has_many :deploy_groups, through: :release_docs, inverse_of: nil

    attr_accessor :builds

    validates :project, :git_sha, :git_ref, presence: true

    def user
      super || NullUser.new(user_id)
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs
    def self.create_release(params)
      Kubernetes::Release.transaction do
        roles = params.delete(:grouped_deploy_group_roles).to_a
        release = create(params) do |release|
          if roles.flatten(1).any? { |dgr| dgr.kubernetes_role.blue_green? }
            release.blue_green_color = begin
              release.previous_succeeded_release&.blue_green_color == "blue" ? "green" : "blue"
            end
          end
        end
        release.send :create_release_docs, roles if release.persisted?
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
        deploy_group = DeployGroup.with_deleted { release_doc.deploy_group }
        [
          deploy_group,
          {
            namespace: release_doc.resources.first.namespace,
            label_selector: self.class.pod_selector(release_id, deploy_group.id, query: true)
          }
        ]
      end
      # avoiding doing a .uniq on clients which might do weird stuff
      scopes.uniq.map { |group, query| [group.kubernetes_cluster.client('v1'), query] }
    end

    def url
      Rails.application.routes.url_helpers.project_kubernetes_release_url(project, self)
    end

    def previous_succeeded_release
      deploy.previous_succeeded_deploy&.kubernetes_release
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

    # Creates a ReleaseDoc per DeployGroupRole
    def create_release_docs(grouped_deploy_group_roles)
      grouped_deploy_group_roles.each do |dgrs|
        dgrs.each do |dgr|
          release_docs.create!(
            deploy_group: dgr.deploy_group,
            kubernetes_release: self,
            kubernetes_role: dgr.kubernetes_role,
            replica_target: dgr.replicas,
            requests_cpu: dgr.requests_cpu,
            requests_memory: dgr.requests_memory,
            limits_cpu: dgr.limits_cpu,
            limits_memory: dgr.limits_memory,
            no_cpu_limit: dgr.no_cpu_limit,
            delete_resource: dgr.delete_resource
          )
        end
      end
      raise Samson::Hooks::UserError, 'No roles or deploy groups given' if release_docs.empty?
    end
  end
end
