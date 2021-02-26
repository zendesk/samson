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
      config = role.role_config_file(reference, project: project, ignore_missing: true, deploy_group: nil)
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
    warnings = apply_namespaces Kubernetes::Cluster.all.to_a, Kubernetes::Namespace.all.to_a
    show_namespace_warnings warnings
    redirect_to action: :index
  end

  def sync
    sync_namespace
    redirect_to @kubernetes_namespace
  end

  private

  def create_callback
    warnings = apply_namespaces Kubernetes::Cluster.all.to_a, [@kubernetes_namespace]
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
    warnings = apply_namespaces Kubernetes::Cluster.all.to_a, [@kubernetes_namespace]
    show_namespace_warnings warnings
  end

  # update namespace only if required to be efficient and even if it the samson request times out to eventually complete
  # @return [Array<String>] errors
  def apply_namespaces(clusters, namespaces)
    Samson::Parallelizer.map clusters do |cluster|
      client = cluster.client("v1")
      existing_namespaces = client.get_namespaces.fetch(:items).each_with_object({}) do |ns, h|
        h[ns.dig(:metadata, :name)] = ns
      end
      namespaces.map do |namespace|
        manifest = namespace.manifest
        next unless apply_needed?(existing_namespaces[namespace.name], manifest)

        begin
          SamsonKubernetes.retry_on_connection_errors do
            client.apply_namespace(Kubeclient::Resource.new(manifest), field_manager: "samson", force: true)
          end
          nil # no error
        rescue StandardError => e
          "Failed to apply namespace #{namespace.name} in cluster #{cluster.name}: #{e.message}"
        end
      end
    end.flatten(1).compact
  end

  # Only update if we change or add anything.
  # This breaks the ability to remove a label that was added earlier, but it allows full sync to work efficiently
  # and eventually succeed even if a single samson request times out.
  # Compares annotations and labels, since nothing else makes sense to change (not spec, managedFields, uid etc)
  def apply_needed?(existing_namespace, manifest)
    return true unless existing_namespace
    [[:metadata, :annotations], [:metadata, :labels]].any? do |path|
      actual = existing_namespace.dig(*path) || {}
      expected = manifest.dig(*path) || (next false)
      !(expected <= actual) # rubocop:disable Style/InverseMethods
    end
  end

  def show_namespace_warnings(warnings)
    return if warnings.empty?
    flash[:warn] = helpers.simple_format("Error applying namespace in some clusters:\n#{warnings.join("\n")}")
  end

  def resource_params
    permitted = [:comment, :template, {project_ids: []}]
    permitted << :name if ["new", "create"].include?(action_name)
    super.permit(*permitted)
  end
end
