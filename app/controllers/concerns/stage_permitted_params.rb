module StagePermittedParams
  def stage_permitted_params
    @stage_permitted_params ||=
      ([ :name, :command, :confirm, :permalink, :dashboard,
        :production,
        :notify_email_address,
        :deploy_on_release,
        :datadog_tags,
        :datadog_monitor_ids,
        :update_github_pull_requests,
        :email_committers_on_automated_deploy_failure,
        :static_emails_on_automated_deploy_failure,
        :use_github_deployment_api,
        deploy_group_ids: [],
        command_ids: [],
        new_relic_applications_attributes: [:id, :name, :_destroy]
      ] + Samson::Hooks.fire(:stage_permitted_params)).freeze
  end
end
