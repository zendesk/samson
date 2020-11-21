# frozen_string_literal: true

class Kubernetes::StagesController < ResourceController
  include CurrentProject
  include CurrentStage

  before_action :authorize_resource!

  # used internally for deploy tab preview as well as an external API to render manifests for external tools
  def manifest_preview
    git_ref = params[:git_ref] || current_project.release_branch || DEFAULT_BRANCH
    git_sha =
      current_project.repository.commit_from_ref(git_ref) ||
      raise(Samson::Hooks::UserError, 'Git reference not found')

    # resolving builds can take some time, best to leave it off by default
    resolve_build = params[:resolve_build] == 'true'

    # build a new deploy/job in memory to process the builds/templates
    job = Job.new(
      deploy: current_stage.deploys.new(project: current_project, reference: git_ref),
      project: current_project,
      user: current_user,
      commit: git_sha
    )
    output = OutputBuffer.new
    deploy_executor = Kubernetes::DeployExecutor.new(job, output)
    release_docs = deploy_executor.preview_release_docs(resolve_build: resolve_build)
    template_fillers = release_docs.flat_map(&:verification_templates)

    # build yaml file with comment header for debugging
    log = "# Manifest preview for #{current_project.name} - #{current_stage.name}. Git ref: #{git_ref} (#{git_sha})\n" +
      yaml_comment(output.messages)
    template_yaml = template_fillers.map { |tf| tf.to_hash(verification: !resolve_build).deep_stringify_keys }
    yaml = log + YAML.dump_stream(*template_yaml)

    render body: yaml
  rescue Samson::Hooks::UserError
    render status: :bad_request, body: yaml_comment($!.message)
  end

  private

  def yaml_comment(message)
    message.split("\n").map { |l| "# #{l}" }.join("\n")
  end
end
