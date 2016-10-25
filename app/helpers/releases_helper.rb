# frozen_string_literal: true
module ReleasesHelper
  def release_label(project, release)
    if release.changeset.hotfix?
      content = link_to(release.version, [project, release], class: "release-label label label-warning")
      warning = content_tag(:span, "", class: "glyphicon glyphicon-exclamation-sign", title: "Hotfix!")

      content + " " + warning
    else
      link_to(release.version, [project, release], class: "release-label label label-success")
    end
  end

  def link_to_deploy_stage(stage, release)
    deploy_params = { reference: release.version }

    if stage.confirm?
      link_to stage.name, new_project_stage_deploy_path(@project, stage, deploy_params)
    else
      link_to stage.name, project_stage_deploys_path(@project, stage, deploy: deploy_params), method: :post
    end
  end
end
