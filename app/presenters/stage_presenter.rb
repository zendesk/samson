class StagePresenter
  def initialize(stage, options = {})
    @stage = stage
    @options = options
  end

  def present
    return unless @stage

    {
      id: @stage.id,
      project: project_presenter(@stage.project).present,
      permalink: @stage.permalink,
      notify_email_address: @stage.notify_email_address,
      order: @stage.order,
      confirm: @stage.confirm,
      datadog_tags: @stage.datadog_tags,
      update_github_pull_requests: @stage.update_github_pull_requests,
      deploy_on_release: @stage.deploy_on_release,
      comment_on_zendesk_tickets: @stage.comment_on_zendesk_tickets,
      production: @stage.production,
      use_github_deployment_api: @stage.use_github_deployment_api,
      dashboard: @stage.dashboard,
      email_committers_on_automated_deploy_failure: @stage.email_committers_on_automated_deploy_failure,
      static_emails_on_automated_deploy_failure: @stage.static_emails_on_automated_deploy_failure,
      datadog_monitor_ids: @stage.datadog_monitor_ids,
      jenkins_job_names: @stage.jenkins_job_names,
      next_stage_ids: @stage.next_stage_ids,
      no_code_deployed: @stage.no_code_deployed,
      docker_binary_plugin_enabled: @stage.docker_binary_plugin_enabled,
      kubernetes: @stage.kubernetes,
      created_at: @stage.created_at,
      updated_at: @stage.updated_at,
      deleted_at: @stage.deleted_at
    }
  end

  private

  def project_presenter(build)
    ProjectPresenter.new(build)
  end
end
