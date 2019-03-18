# frozen_string_literal: true
module Kubernetes
  module EventReader
    class << self
      def events(client, resource)
        SamsonKubernetes.retry_on_connection_errors do
          selector = ["involvedObject.name=#{resource.dig_fetch(:metadata, :name)}"]

          # do not query for nil uid ... rather show events for old+new resource when creation failed
          if uid = resource.dig_fetch(:metadata, :uid)
            selector << "involvedObject.uid=#{uid}"
          end

          client.get_events(
            namespace: resource.dig(:metadata, :namespace),
            field_selector: selector.join(",")
          ).fetch(:items)
        end
      end
    end
  end
end
