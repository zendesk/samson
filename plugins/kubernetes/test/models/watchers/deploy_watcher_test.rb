# rubocop:disable Metrics/LineLength
require_relative "../../test_helper"
require 'celluloid/current'

SingleCov.covered! uncovered: 33

describe Watchers::DeployWatcher do
  let(:environment) { environments(:production) }
  let(:a_previous_release) { kubernetes_releases(:live_release) }
  let(:current_release) { kubernetes_releases(:created_release) }
  let(:project) { current_release.project }

  before do
    # Disable multithreading so celluloid stays in the same transaction
    ActiveRecord::Base.stubs(connection: ActiveRecord::Base.connection)
    Celluloid.shutdown
    Celluloid.boot
    Watchers::DeployWatcher.any_instance.stubs(:terminate_watcher)
    Watchers::DeployWatcher.any_instance.stubs(:last_release).returns(current_release)
    Kubernetes::Cluster.any_instance.stubs(:client).returns(Kubeclient::Client.new('http://cluster.localhost'))
  end

  after { Celluloid.shutdown }

  describe '#initialize' do
    it 'gets in sync with the cluster and starts listening for pod events' do
      Watchers::DeployWatcher.any_instance.expects(:sync_with_cluster).once
      Watchers::DeployWatcher.any_instance.expects(:watch).once
      create_deploy_watcher
    end
  end

  describe '#sync_with_cluster' do
    it 'fetches the current state from the Kubernetes cluster' do
      all_pods = []
      expect_pod_list(current_release) do |pods|
        all_pods.push(*pods)
      end

      watcher = create_deploy_watcher

      watcher.send(:rcs).wont_be_empty
      watcher.send(:rcs).size.must_equal all_pods.map { |pod| pod.metadata.labels.rc_unique_identifier }.uniq.size
    end

    it 'reconciles old releases marking all of them as dead' do
      expect_pod_list(current_release)

      releases = project.kubernetes_releases.excluding(current_release.id)
      releases.all?(&:dead?).must_equal false

      create_deploy_watcher

      releases.reload.all?(&:dead?).must_equal true
    end

    it 'reconciles db with cluster and detects if the current release is spinning up ' do
      current_release.created?.must_equal true

      # Expecting only one pod (target = 2)
      expect_pod_list(current_release, &:pop)
      create_deploy_watcher
      current_release.reload.spinning_up?.must_equal true
    end

    it 'reconciles db with cluster and detects if the current release is spinning down' do
      current_release.created?.must_equal true

      # Expecting all pods to be live
      expect_pod_list(current_release)
      create_deploy_watcher
      current_release.reload.live?.must_equal true

      # Expecting one single pod to be dead
      expect_pod_list(current_release) do |pods|
        pods[0].status.conditions.find { |c| c.type == 'Ready' }.status = 'False'
      end
      create_deploy_watcher
      current_release.reload.spinning_down?.must_equal true
    end

    it 'reconciles db with cluster and detects if the current release is dead' do
      current_release.created?.must_equal true

      # Expecting all pods to be live
      expect_pod_list(current_release)
      create_deploy_watcher
      current_release.reload.live?.must_equal true

      # Expecting all pods to be dead
      expect_pod_list(current_release) do |pods|
        pods.each { |pod| pod.status.conditions.find { |c| c.type == 'Ready' }.status = 'False' }
      end
      create_deploy_watcher
      current_release.reload.dead?.must_equal true
    end
  end

  describe '#watch' do
    it 'recognizes deploy as ongoing until all pods are live' do
      # Expect empty Pod list from the Cluster (not created yet)
      expect_pod_list(current_release, &:clear)

      watcher = create_deploy_watcher

      current_release.release_docs.first.tap do |release_doc|
        rc_unique_identifier = "#{release_doc.replication_controller_name}-#{rand(100000)}"
        release_doc.replica_target.times do |i|
          msg = Watchers::BaseClusterWatcher.topic_message(create_msg(release_doc, rc_unique_identifier: rc_unique_identifier, name: "pod-#{i}", ready: 'True'))
          watcher.send(:handle_event, 'some topic', msg)
        end
      end

      current_release.reload
      watcher.send(:deploy_finished?, project).must_equal false
    end

    it 'recognizes deploy as finished when all pods are live' do
      # Expect empty Pod list from the Cluster (not created yet)
      expect_pod_list(current_release, &:clear)

      watcher = create_deploy_watcher

      current_release.release_docs.each do |release_doc|
        rc_unique_identifier = "#{release_doc.replication_controller_name}-#{rand(100000)}"
        release_doc.replica_target.times do |i|
          msg = Watchers::BaseClusterWatcher.topic_message(create_msg(release_doc, rc_unique_identifier: rc_unique_identifier, name: "pod-#{i}", ready: 'True'))
          watcher.send(:handle_event, 'some topic', msg)
        end
      end

      current_release.reload
      watcher.send(:deploy_finished?, project).must_equal true
    end

    it 'sends SSE event when event received' do
      # Expect empty Pod list from the Cluster (not created yet)
      expect_pod_list(current_release, &:clear)

      watcher = create_deploy_watcher

      current_release.release_docs.each do |release_doc|
        rc_unique_identifier = "#{release_doc.replication_controller_name}-#{rand(100000)}"
        release_doc.replica_target.times do |i|
          SseRailsEngine.expects(:send_event).with('k8s', create_sse_data(release_doc, i + 1))

          msg = Watchers::BaseClusterWatcher.topic_message(create_msg(release_doc, rc_unique_identifier: rc_unique_identifier, name: "pod-#{i}", ready: 'True'))
          watcher.send(:handle_event, 'some topic', msg)
        end
      end
    end
  end

  def create_deploy_watcher
    Watchers::DeployWatcher.send(:new, project)
  end

  def expect_pod_list(release)
    environment.cluster_deploy_groups.each do |cdg|
      pod_list = pod_list(release, cdg)
      yield pod_list if block_given?
      Kubeclient::Client.any_instance.expects(:get_pods).
        with(namespace: cdg.namespace, label_selector: "project_id=#{project.id}").
        returns(pod_list)
    end
  end

  def pod_list(release, cdg)
    [].tap do |list|
      release.release_docs.each do |release_doc|
        # In the Cluster, the RC unique identifier is unique per deploy group / namespace
        rc_unique_identifier = "#{release_doc.replication_controller_name}-#{rand(100000)}"
        release_doc.replica_target.times do |i|
          pod = pod_list_item(i, rc_unique_identifier, release_doc, cdg.namespace)
          list << RecursiveOpenStruct.new(pod, recurse_over_arrays: true) if release_doc.deploy_group == cdg.deploy_group
        end
      end
    end
  end

  def pod_list_item(index, rc_unique_identifier, release_doc, namespace)
    {
      'metadata': {
        'name': "pod-#{index}",
        'namespace': namespace,
        'labels': {
          'project_id': release_doc.kubernetes_release.project.id,
          'release_id': release_doc.kubernetes_release.id,
          'deploy_group_id': release_doc.deploy_group.id,
          'role_id': release_doc.kubernetes_role.id,
          'rc_unique_identifier': rc_unique_identifier
        }
      },
      'status': {
        'phase': 'Running',
        'conditions': [
          {
            'type': 'Ready',
            'status': 'True'
          }
        ]
      }
    }
  end

  def create_msg(release_doc, rc_unique_identifier:, type: 'ADDED', status: 'Running', name:, ready: 'True')
    Watchers::Events::PodEvent.new(
      RecursiveOpenStruct.new({
        type: type,
        object: {
          kind: 'Pod',
          metadata: {
            name: name,
            labels: {
              project_id: release_doc.kubernetes_release.project.id,
              release_id: release_doc.kubernetes_release.id,
              deploy_group_id: release_doc.deploy_group.id,
              role_id: release_doc.kubernetes_role.id,
              rc_unique_identifier: rc_unique_identifier
            }
          },
          status: {
            phase: status,
            conditions: [
              { type: 'Ready', status: ready }
            ]
          }
        }
      }, recurse_over_arrays: true)
    )
  end

  def create_sse_data(release_doc, live_replicas)
    {
      project: release_doc.kubernetes_release.project.id,
      role: {
        id: release_doc.kubernetes_role.id,
        name: release_doc.kubernetes_role.name
      },
      deploy_group: {
        id: release_doc.deploy_group.id,
        name: release_doc.deploy_group.name
      },
      release: {
        id: release_doc.kubernetes_release.id,
        build: release_doc.kubernetes_release.build.label,
        target_replicas: release_doc.replica_target,
        live_replicas: live_replicas,
        failed: release_doc.failed?,
        failed_pods: 0
      }
    }
  end
end
