module DeployStatusHelper

  STATUS_MAPPING = {
    "running" => "label-primary",
    "succeeded" => "label-success",
    "failed" => "label-danger",
    "pending" => "label-default",
    "cancelling" => "label-warning",
    "cancelled" => "label-danger"
  }

  def deploy_status_for_label(key)
    STATUS_MAPPING.fetch(key, "label-info")
  end
end
