# frozen_string_literal: true
module ReleasesHelper
  GITHUB_STATUS_ICONS = {
    "success" => "ok",
    "failure" => "remove",
    "missing" => "minus",
    "pending" => "hourglass",
    "error" => "exclamation-sign"
  }.freeze

  GITHUB_STATUS_TEXT_LABELS = {
    "success" => "success",
    "failure" => "danger",
    "missing" => "muted",
    "pending" => "primary",
    "error" => "warning"
  }.freeze

  def release_label(project, release)
    link_to(
      release.version,
      [project, release],
      class: "release-label label label-success", data: {ref: release.version}
    )
  end

  def github_commit_status_icon(status)
    failed = status.failed
    succeeded = status.succeeded
    errored = status.errored
    pending = status.pending

    status_counts = []
    status_counts << "#{failed.count} failed" if failed.any?
    status_counts << "#{succeeded.count} succeeded" if succeeded.any?
    status_counts << "#{errored.count} errored" if errored.any?
    status_counts << "#{pending.count} pending" if pending.any?

    title = "Github status: #{status_counts.join(', ')}"

    icon = GITHUB_STATUS_ICONS.fetch(status.state)
    text = GITHUB_STATUS_TEXT_LABELS.fetch(status.state)

    icon_tag icon, class: "text-#{text}", 'data-toggle': "tooltip", 'data-placement': "right", title: title
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
