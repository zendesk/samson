require 'celluloid/current'

module Kubernetes
  module Util
    def self.parse_file(contents, filepath)
      filename = File.basename(filepath).downcase

      if filename.ends_with?('.yml', '.yaml')
        # NOTE: this will always return an array of entries
        YAML.load_stream(contents, filepath)
      elsif filename.ends_with?('.json')
        JSON.parse(contents)
      else
        fail "Unknown file type: #{filename}"
      end
    end

    def self.log(message, extra_info = {})
      @output_file ||= File.open(ENV['KUBER_LOGFILE'] || File.join(Rails.root, 'log', 'kubernetes.log'), 'a')

      @output_file.write({ message: message }.merge(extra_info).to_json + "\n")
      @output_file.flush
      message
    end

    def self.pod_watcher_symbol(cluster)
      "cluster_pod_watcher_#{cluster.id}".to_sym
    end

    def self.start_watcher(cluster)
      watcher_name = pod_watcher_symbol(cluster)
      Watchers::ClusterPodWatcher.supervise as: watcher_name, args: [cluster.client]
    end

    def self.restart_watcher(cluster)
      watcher = Celluloid::Actor[pod_watcher_symbol(cluster)]
      watcher.terminate if watcher and watcher.alive?
      start_watcher(cluster)
    end
  end
end
