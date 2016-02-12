module Kubernetes
  module Api
    # Module used by the DeployWatcher to identify a Pod as failed.
    module FailedPod
      def failed?
        true
      end
    end
  end
end
