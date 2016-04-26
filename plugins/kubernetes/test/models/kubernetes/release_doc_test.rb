require_relative "../../test_helper"

SingleCov.covered! uncovered: 37

describe Kubernetes::ReleaseDoc do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }

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
end

