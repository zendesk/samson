# frozen_string_literal: true
module ReleasesHelper
  STATUS_ICONS = {
    "success" => "ok",
    "failure" => "remove",
    "missing" => "minus",
    "pending" => "hourglass"
  }

  STATUS_TEXT_LABELS = {
    "success" => "success",
    "failure" => "danger",
    "missing" => "muted",
    "pending" => "primary"
  }

  def release_label(project, release)
    link_to(
      release.version,
      [project, release],
      class: "release-label label label-success", data: {ref: release.version}
    )
  end

  def status_glyphicon(status_state)
    icon = STATUS_ICONS.fetch(status_state)
    text = STATUS_TEXT_LABELS.fetch(status_state)

    icon_tag icon, class: "text-#{text}"
  end

  def link_to_deploy_stage(stage, release)
    deploy_params = {reference: release.version}

    if stage.confirm?
      link_to stage.name, new_project_stage_deploy_path(@project, stage, deploy_params)
    else
      link_to stage.name, project_stage_deploys_path(@project, stage, deploy: deploy_params), method: :post
    end
  end
end
