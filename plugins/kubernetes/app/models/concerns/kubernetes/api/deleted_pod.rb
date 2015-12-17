module Kubernetes
  module Api
    # Module used by the DeployWatcher to identify a Pod as deleted.
    module DeletedPod
      def live?
        false
      end
    end
  end
end
