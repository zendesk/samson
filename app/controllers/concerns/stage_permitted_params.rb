# frozen_string_literal: true
module StagePermittedParams
  def stage_permitted_params
    @stage_permitted_params ||= ([
      :name,
      :command,
      :confirm,
      :permalink,
      :dashboard,
      :production,
      :notify_email_address,
      :deploy_on_release,
      :update_github_pull_requests,
      :email_committers_on_automated_deploy_failure,
      :static_emails_on_automated_deploy_failure,
      :use_github_deployment_api,
      :no_code_deployed,
      :is_template,
      {
        deploy_group_ids: [],
        command_ids: []
      }
    ] + Samson::Hooks.fire(:stage_permitted_params).flatten).freeze
  end
end
