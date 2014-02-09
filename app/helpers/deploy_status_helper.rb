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
end
