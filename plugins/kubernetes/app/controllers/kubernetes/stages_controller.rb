# frozen_string_literal: true

class Kubernetes::StagesController < ResourceController
  include CurrentProject
  include CurrentStage

  DEFAULT_BRANCH = "master"

  before_action :authorize_resource!

  def manifest_preview
    # find ref and sha ... sha takes priority since it's most accurate
    git_sha = params[:git_sha]
    git_ref = params[:git_ref] || git_sha || current_project.release_branch || DEFAULT_BRANCH
    git_sha ||= current_project.repository.commit_from_ref(git_ref)
    if git_sha.empty?
      return render body: '# Git reference not found', content_type: 'application/yaml'
    end

    # build a new deploy/job in memory to process the builds/templates
    resolve_build = params[:resolve_build] == 'true'
    job = Job.new(
      deploy: current_stage.deploys.new(project: current_project, reference: git_ref || git_sha),
      project: current_project,
      user: current_user,
      commit: git_sha
    )
    output = OutputBuffer.new
    deploy_executor = Kubernetes::DeployExecutor.new(job, output)
    release_docs = deploy_executor.preview(resolve_build: resolve_build)

    template_fillers = release_docs.map(&:verification_template)
    log = "# Manifest preview for #{current_project.name} - #{current_stage.name}. Git ref: #{git_ref} (#{git_sha})\n" +
      yaml_comment(output.messages)
    yaml = log + YAML.dump_stream(*template_fillers.map { |tf| tf.to_hash(verification: !resolve_build).deep_stringify_keys })
    render body: yaml
  rescue Samson::Hooks::UserError
    render status: 400, body: yaml_comment($!.message)
  end

  private

  def yaml_comment(message)
    "# #{message.split("\n").join("\n# ")}\n"
  end
end
