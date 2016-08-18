class ProjectPresenter
  def initialize(project, options = {})
    @project = project
    @options = options
  end

  def present
    return unless @project

    {
      id: @project.id,
      name: @project.name,
      repository_url: @project.repository_url,
      deleted_at: @project.deleted_at,
      created_at: @project.created_at,
      updated_at: @project.updated_at,
      release_branch: @project.release_branch,
      permalink: @project.permalink,
      description: @project.description,
      owner: @project.owner,
      deploy_with_docker: @project.deploy_with_docker,
      auto_release_docker_image: @project.auto_release_docker_image
    }.as_json
  end
end
