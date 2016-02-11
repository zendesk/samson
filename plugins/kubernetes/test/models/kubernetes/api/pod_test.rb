require_relative '../../../test_helper'

describe Kubernetes::Api::Pod do
  let(:pod_name) { 'test_name' }

  describe 'using kubeclient pod' do
    describe 'with running pod' do
      let(:pod) { Kubernetes::Api::Pod.new(build_kubeclient_pod) }

      it 'returns proper name' do
        pod.name.must_equal pod_name
      end

      it 'correctly identifies ready state' do
        assert pod.live?
      end
    end

    describe 'with dead pod' do
      let(:kubeclient_pod) { build_kubeclient_pod }

      it 'correctly identifies not ready state using phase' do
        kubeclient_pod.status.phase = 'Failed'
        pod = Kubernetes::Api::Pod.new(kubeclient_pod)
        refute pod.live?
      end

      it 'correctly identifies not ready state using condition status' do
        kubeclient_pod.status.conditions.first.status = 'False'
        pod = Kubernetes::Api::Pod.new(kubeclient_pod)
        refute pod.live?
      end

      it 'correctly identifies not ready state when ready condition missing' do
        kubeclient_pod.status.conditions.first.type = 'Unknown'
        pod = Kubernetes::Api::Pod.new(kubeclient_pod)
        refute pod.live?
      end

      it 'correctly identifies not ready state when conditions missing' do
        kubeclient_pod.status.delete_field 'conditions'
        pod = Kubernetes::Api::Pod.new(kubeclient_pod)
        refute pod.live?
      end
    end
  end

  describe 'using watch notice' do
    describe 'with running pod' do
      let(:pod) { Kubernetes::Api::Pod.new(build_watch_notice.object) }

      it 'returns proper name' do
        pod.name.must_equal pod_name
      end

      it 'correctly identifies ready state' do
        assert pod.live?
      end
    end

    describe 'with dead pod' do
      let(:watch_notice_object) { build_watch_notice.object }

      it 'correctly identifies not ready state using phase' do
        watch_notice_object.status.phase = 'Failed'
        pod = Kubernetes::Api::Pod.new(watch_notice_object)
        refute pod.live?
      end

      it 'correctly identifies not ready state using condition status' do
        watch_notice_object.status.conditions.first['status'] = 'False'
        pod = Kubernetes::Api::Pod.new(watch_notice_object)
        refute pod.live?
      end

      it 'correctly identifies not ready state when ready condition missing' do
        watch_notice_object.status.conditions.first['type'] = 'Unknown'
        pod = Kubernetes::Api::Pod.new(watch_notice_object)
        refute pod.live?
      end

      it 'correctly identifies not ready state when conditions missing' do
        watch_notice_object.status.delete_field 'conditions'
        pod = Kubernetes::Api::Pod.new(watch_notice_object)
        refute pod.live?
      end
    end
  end

  private

  def build_kubeclient_pod
    Kubeclient::Pod.new(
        JSON.parse(
            %({"metadata": {"name": "#{pod_name}"},
               "status": {"phase": "Running",
                          "conditions": [{"type": "Ready", "status": "True"}]}})))
  end

  def build_watch_notice
    Kubeclient::Common::WatchNotice.new(
        JSON.parse(
            %({"type": "MODIFIED", "object": {"metadata": {"name": "#{pod_name}"},
                                              "status": {"phase": "Running",
                                                         "conditions": [{"type": "Ready", "status": "True"}]}}})))
  end
end
