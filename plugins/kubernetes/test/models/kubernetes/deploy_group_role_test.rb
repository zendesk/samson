require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployGroupRole do
  let(:doc) { kubernetes_deploy_group_roles(:test_pod_1_app_server) }
end
