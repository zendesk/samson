module DeployStatusHelper

  STATUS_MAPPING = {
    "running" => "primary",
    "succeeded" => "success",
    "failed" => "danger",
    "pending" => "default",
    "cancelling" => "warning",
    "cancelled" => "danger"
  }

  def deploy_status(key, prefix = nil)
    status = STATUS_MAPPING.fetch(key, "info")
    if prefix
      prefix + "-" + status
    else
      status
    end
  end

  def deploy_status_icon(status)
    icon = {
      "succeeded" => "check",
      "failed" => "fire",
      "errored" => "exclamation-sign",
      "cancelled" => "remove",
    }[status]
    tag :span, class: "glyphicon glyphicon-#{icon}", title: status if icon
  end
end
