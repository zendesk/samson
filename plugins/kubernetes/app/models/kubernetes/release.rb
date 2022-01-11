# frozen_string_literal: true
module Kubernetes
  class Release < ActiveRecord::Base
    CRD_CREATING = {
      "ConstraintTemplate" => [:spec, :crd] # OPA
    }.freeze

    self.table_name = 'kubernetes_releases'

    belongs_to :user, inverse_of: false
    belongs_to :project, inverse_of: :kubernetes_releases
    belongs_to :deploy, inverse_of: :kubernetes_release
    has_many :release_docs,
      class_name: 'Kubernetes::ReleaseDoc',
      foreign_key: 'kubernetes_release_id',
      dependent: :destroy,
      inverse_of: :kubernetes_release
    has_many :deploy_groups, through: :release_docs, inverse_of: false

    attr_accessor :builds

    validates :project, :git_sha, :git_ref, presence: true

    def user
      super || NullUser.new(user_id)
    end

    # Creates a new Kubernetes Release and corresponding ReleaseDocs
    def self.build_release_with_docs(params)
      roles = params.delete(:grouped_deploy_group_roles).to_a
      release = new(params) do |release|
        # We always set the blue green color but the template filler might not always use it.
        # This allows us to support deploy-specific features like env vars from config maps.
        release.blue_green_color =
          release.previous_succeeded_release&.blue_green_color == "blue" ? "green" : "blue"
      end
      release.send :build_release_docs, roles if release.valid?
      release
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
    def clients(version)
      scopes = release_docs.map do |release_doc|
        deploy_group = DeployGroup.with_deleted { release_doc.deploy_group }
        [
          deploy_group,
          {
            namespace: release_doc.resources.first.namespace,
            label_selector: self.class.pod_selector(id, deploy_group.id, query: true)
          }
        ]
      end

      # avoiding doing a .uniq on clients which might trigger api calls
      scopes.uniq.map { |group, query| [group.kubernetes_cluster.client(version), query] }
    end

    def previous_succeeded_release
      deploy.previous_succeeded_deploy&.kubernetes_release
    end

    private

    # Creates a ReleaseDoc per DeployGroupRole
    def build_release_docs(grouped_deploy_group_roles)
      grouped_deploy_group_roles.each do |dgrs|
        dgrs.each do |dgr|
          release_docs.build(
            deploy_group_role: dgr,
            deploy_group: dgr.deploy_group,
            kubernetes_release: self,
            kubernetes_role: dgr.kubernetes_role,
            replica_target: dgr.replicas,
            delete_resource: dgr.delete_resource
          )
        end
      end

      # to verify the template when creating a new CRD we need to know which CRDs are in this deploy
      resources = release_docs.uniq(&:kubernetes_role).flat_map { |rd| rd.send :raw_template }
      crds =
        resources.select { |t| t[:kind] == "CustomResourceDefinition" } + # vanilla
        CRD_CREATING.flat_map do |kind, nesting|
          resources.select { |t| t[:kind] == kind }.map { |t| t.dig(*nesting) }
        end
      created_cluster_resources = crds.each_with_object({}) do |crd, h|
        h[crd.dig(:spec, :names, :kind)] = {"namespaced" => crd.dig(:spec, :scope) == "Namespaced"}
      end

      release_docs.each { |rd| rd.created_cluster_resources = created_cluster_resources }

      raise Samson::Hooks::UserError, 'No roles or deploy groups given' if release_docs.empty?
    end
  end
end
