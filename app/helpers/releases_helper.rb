module ReleasesHelper
  def link_to_deploy_stage(stage, release)
    deploy_params = { reference: release.version, stage_id: stage.id }

    if stage.confirm_before_deploying?
      link_to stage.name, new_project_deploy_path(@project, deploy_params)
    else
      link_to stage.name, project_deploys_path(@project, deploy: deploy_params), method: :post
    end
  end
end
