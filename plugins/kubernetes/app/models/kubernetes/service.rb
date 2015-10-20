module Kubernetes
  # Convenience wrapper around the 'Service' object we can get from the K8S API
  class Service
    attr_reader :deploy_group, :role, :name, :ip_address, :port_info

    def initialize(deploy_group: nil, role: nil)
      @deploy_group = deploy_group
      @role = role
      @port_info = []
      @name = role.try(:service_name)
    end

    def namespace
      deploy_group.kubernetes_namespace
    end

    def running?
      service_object.present?
    end

    def proxy_address
      "#{example_node_ip}:#{node_ports.first}" if running?
    end

    def example_node_ip
      node = client.get_nodes.first
      node.spec.externalID if node
    end

    # The set of ports that are exposed on each Kubernetes minion. Traffic sent
    # to this port on any minion will be proxied to the Pods in this service.
    def node_ports
      fetch_service if @service_object.nil?
      @port_info.map(&:nodePort)
    end

    # Returns an array of OpenStructs containing the list of Pods that this
    # service routes traffic to. Each object return has the following attributes:
    #   `pod_ip` : IP address of the Pod
    #   `pod_name` : name of the Pod
    #   `ready?` : true if the Pod is ready and accepting traffic
    def endpoints
      return [] if endpoint_object.nil?

      results = []

      # https://htmlpreview.github.io/?https://github.com/kubernetes/kubernetes/HEAD/docs/api-reference/v1/definitions.html#_v1_endpoints
      endpoint_object.subsets.each do |subset|
        [:addresses, :notReadyAddresses].each do |attr|
          next if subset[attr].blank?

          subset[attr].each do |address|
            if address.targetRef.kind == 'Pod'
              results << OpenStruct.new(pod_ip: address.ip,
                                        pod_name: address.targetRef.name,
                                        ready?: (attr == :addresses))
            end
          end
        end
      end

      results
    end

    def service_object
      @service_object || fetch_service
    end

    def endpoint_object
      @endpoint_object || fetch_endpoint
    end

    private

    def fetch_service
      @service_object = client.get_service(name, namespace)
      @name = @service_object.metadata.name
      @ip_address = @service_object.spec.clusterIP
      @port_info = @service_object.spec.ports || []
      @service_object
    rescue KubeException => e
      raise e unless e.error_code == 404
      nil
    end

    def fetch_endpoint
      @endpoint_object = client.get_endpoints(namespace: namespace,
                                              field_selector: "metadata.name=#{name}").first
    end

    def client
      deploy_group.kubernetes_cluster.client
    end
  end
end
