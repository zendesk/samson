module ReleasesHelper
  def release_label(project, release)
    path = project_release_path(project, release)
    classes = %w(release-label label)

    if release.changeset.hotfix?
      classes << "label-warning"
    else
      classes << "label-success"
    end

    content = link_to(release.version, path, class: classes.join(" "))

    if release.changeset.hotfix?
      warning = content_tag(:span, "", class: "glyphicon glyphicon-exclamation-sign", title: "Hotfix!")
      content + " " + warning
    else
      content
    end
  end

  def link_to_deploy_stage(stage, release)
    deploy_params = { reference: release.version, stage_id: stage.id }

    if stage.confirm_before_deploying?
      link_to stage.name, new_project_deploy_path(@project, deploy_params)
    else
      link_to stage.name, project_deploys_path(@project, deploy: deploy_params), method: :post
    end
  end
end
