require_relative "../../test_helper"

SingleCov.covered! uncovered: 29

describe Kubernetes::ReleaseDoc do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }

  before { kubernetes_fake_raw_template }

  describe "#ensure_service" do
    it "does nothing when no service is defined" do
      doc.ensure_service.must_equal "no Service defined"
    end

    it "does nothing when no service is running" do
      doc.stubs(service: stub(running?: true))
      doc.ensure_service.must_equal "Service already running"
    end

    it "creates the service when it does not exist" do
      doc.stubs(service: stub(running?: false))
      doc.expects(:client).returns(stub(create_service: nil))
      doc.ensure_service.must_equal "creating Service"
    end
  end

  describe "#deploy_to_kubernetes" do
    let(:client) { doc.send(:extension_client) }

    it "creates when deploy does not exist" do
      client.expects(:get_deployment).returns false
      client.expects(:create_deployment)
      doc.deploy_to_kubernetes
    end

    it "updates when deploy does exist" do
      client.expects(:get_deployment).returns true
      client.expects(:update_deployment)
      doc.deploy_to_kubernetes
    end

    it "can manage daemonsets" do
      doc.send(:deploy_yaml).send(:template).kind = 'DaemonSet'
      client.expects(:get_daemon_set).returns true
      client.expects(:update_daemon_set)
      doc.deploy_to_kubernetes
    end
  end
end

