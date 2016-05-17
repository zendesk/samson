require_relative "../../test_helper"

SingleCov.covered! uncovered: 18

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

    describe "when service does not exist" do
      before do
        doc.stubs(service: stub(running?: false))
        doc.raw_template << "\n" << {'kind' => 'Service', 'metadata' => {}, 'spec' => {}}.to_yaml
        doc.kubernetes_role.update_column(:service_name, "app-server")
      end

      it "creates the service when it does not exist" do
        doc.expects(:client).returns(stub(create_service: nil))
        doc.ensure_service.must_equal "creating Service"
      end

      it "fails when trying to deploy a generated service" do
        doc.kubernetes_role.update_column(:service_name, "app-server#{Kubernetes::Role::GENERATED}1211212")
        e = assert_raises Samson::Hooks::UserError do
          doc.ensure_service
        end
        e.message.must_equal "Service name for role app_server was generated and needs to be changed before deploying."
      end

      it "fails when service is required by the role, but not defined" do
        assert doc.raw_template.sub!('Service', 'Nope')
        e = assert_raises Samson::Hooks::UserError do
          doc.ensure_service
        end
        e.message.must_equal "Template kubernetes/app_server.yml has 0 services, having 1 section is valid."
      end

      it "fails when multiple services are defined and we would only ensure the first one" do
        doc.raw_template << "\n" << {'kind' => 'Service'}.to_yaml

        e = assert_raises Samson::Hooks::UserError do
          doc.ensure_service
        end
        e.message.must_equal "Template kubernetes/app_server.yml has 2 services, having 1 section is valid."
      end
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

