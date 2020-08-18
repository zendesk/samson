# frozen_string_literal: true
class Kubernetes::NamespacesController < ResourceController
  before_action :authorize_admin!, except: [:show, :index, :preview]
  before_action :set_resource, only: [:show, :update, :destroy, :new, :create, :sync]

  def new
    @kubernetes_namespace.template ||= {"metadata" => {"labels" => {"team" => "fill-me-in"}}}.to_yaml
    super
  end

  def update
    super template: :show
    sync_namespace if @kubernetes_namespace.previous_changes.key?(:template)
  end

  # changing resource names means we will duplicate resources and not clean up the old ones, so avoid it
  def preview
    project = Project.find params.require(:project_id)
    reference = project.release_branch.presence || "master"
    errors = []

    project.kubernetes_roles.not_deleted.each do |role|
      config = role.role_config_file(
        reference,
        project: project, ignore_missing: true, ignore_errors: false, deploy_group: nil
      )
      unless config
        errors << "Unable to read #{role.config_file}"
        next
      end

      config.elements.each do |element|
        kind = element[:kind]
        name = element.dig(:metadata, :name)

        # name was never changed
        next if Kubernetes::RoleValidator::IMMUTABLE_NAME_KINDS.include?(kind) ||
          Kubernetes::RoleValidator.keep_name?(element)

        # correct name was configured
        expected = (kind == "Service" ? role.service_name : role.resource_name)
        next if name == expected

        errors << "Project config #{config.path} #{kind} #{name} would be duplicated with name #{expected}"
      end
    end

    if errors.any?
      redirect_to({action: :index}, alert: helpers.simple_format(errors.join("\n")))
    else
      redirect_to({action: :index}, notice: "No name change expected")
    end
  end

  def sync_all
    warnings = apply_namespaces Kubernetes::Cluster.all, Kubernetes::Namespace.all
    show_namespace_warnings warnings
    redirect_to action: :index
  end

  def sync
    sync_namespace
    redirect_to @kubernetes_namespace
  end

  private

  def create_callback
    warnings = apply_namespaces Kubernetes::Cluster.all, [@kubernetes_namespace]
    warnings += copy_secrets(
      ENV['KUBERNETES_COPY_SECRETS_TO_NEW_NAMESPACE'].to_s.split(","),
      from: 'default',
      to: @kubernetes_namespace.name
    )
    show_namespace_warnings warnings
  end

  def copy_secrets(secret_names, from:, to:)
    secret_names.flat_map do |secret_name|
      Kubernetes::Cluster.all.map do |cluster|
        client = cluster.client('v1')
        begin
          secret = SamsonKubernetes.retry_on_connection_errors { client.get_secret(secret_name, from) }
          secret[:metadata][:namespace] = to
          # remove things we should not set
          [:resourceVersion, :selfLink, :uid, :creationTimestamp, :annotations].each do |d|
            secret[:metadata].delete(d)
          end
          SamsonKubernetes.retry_on_connection_errors { client.create_secret(secret) }
        rescue StandardError => e
          "Failed to copy secret #{secret_name} to #{to} in cluster #{cluster.name}: #{e.message}"
        else
          nil
        end
      end
    end.compact
  end

  def sync_namespace
    warnings = apply_namespaces Kubernetes::Cluster.all, [@kubernetes_namespace]
    show_namespace_warnings warnings
  end

  # @return [Array<String>] errors
  def apply_namespaces(clusters, namespaces)
    Samson::Parallelizer.map clusters.to_a.product(namespaces) do |cluster, namespace|
      begin
        SamsonKubernetes.retry_on_connection_errors do
          cluster.client('v1').apply_namespace(
            Kubeclient::Resource.new(namespace.manifest), field_manager: "samson", force: true
          )
        end
        nil
      rescue StandardError => e
        "Failed to apply namespace #{namespace.name} in cluster #{cluster.name}: #{e.message}"
      end
    end.compact
  end

  def show_namespace_warnings(warnings)
    return if warnings.empty?
    flash[:warn] = helpers.simple_format("Error applying namespace in some clusters:\n" + warnings.join("\n"))
  end

  def resource_params
    permitted = [:comment, :template, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
