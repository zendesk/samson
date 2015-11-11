require 'celluloid'
require 'celluloid/autostart'

module Watchers
  # Instantiated when a Kubernetes deploy is created to watch the status
  class DeployWatcher
    include Celluloid
    include Celluloid::Notifications

    finalizer :on_termination

    def initialize(release)
      @release = release
    end

    def watch
      @release.release_docs.each do |release_doc|
        subscribe "#{release_doc.replication_controller_name}", :handle_update
      end
    end

    def handle_update(topic, data)
      release_doc = release_doc_from_rc_name(topic)
      update_replica_count(release_doc, data)
      SseRailsEngine.send_event(
        'k8s',
        project: @release.project.id,
        release: @release.id,
        role: release_doc.kubernetes_role.name,
        deploy_group: release_doc.deploy_group.name,
        target_replicas: release_doc.replica_target,
        live_replicas: release_doc.replicas_live
      )
      terminate if deploy_finished?
    end

    private

    def deploy_finished?
      @release.release_docs.all?(&:live?)
    end

    def release_doc_from_rc_name(name)
      @release.release_docs.select { |doc| doc.replication_controller_name == name }.first
    end

    def on_termination
      @release.release_is_live!
      SseRailsEngine.send_event(
        'k8s',
        project: @release.project.id,
        release: @release.id,
        msg: 'Deploy has finished!'
      )
    end

    def update_replica_count(release_doc, rc)
      release_doc.update_replica_count(rc[:object][:status][:replicas])
      @release.update_columns(status: :spinning_up) if @release.status.to_sym == :created
    end
  end
end
