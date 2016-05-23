Admin::DeployGroupsController.class_eval do
  prepend Kubernetes::DeployGroupPermittedParams
end
