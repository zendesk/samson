require_relative "../../test_helper"

SingleCov.covered! uncovered: 16

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

  describe "#deploy" do
    let(:client) { doc.send(:extension_client) }

    describe "deployment" do
      it "creates when deploy does not exist" do
        client.expects(:get_deployment).raises(KubeException.new(1, 2, 3))
        client.expects(:create_deployment)
        doc.deploy
      end

      it "updates when deploy exists" do
        client.expects(:get_deployment).returns true
        client.expects(:update_deployment)
        doc.deploy
      end
    end

    describe "daemonset" do
      before do
        doc.send(:deploy_yaml).send(:template).kind = 'DaemonSet'
        doc.stubs(:sleep)
      end

      it "creates when daemonset does not exist" do
        client.expects(:get_daemon_set).raises(KubeException.new(1, 2, 3))
        client.expects(:create_daemon_set)
        doc.deploy
      end

      it "deletes and created when daemonset exists without pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(2).returns(
          stub(status: stub(currentNumberScheduled: 0, numberMisscheduled: 0)), # initial check
          stub(status: stub(currentNumberScheduled: 0, numberMisscheduled: 0))  # check for running
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        doc.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(4).returns(
          stub(status: stub(currentNumberScheduled: 1, numberMisscheduled: 1)), # initial check
          stub(status: stub(currentNumberScheduled: 1, numberMisscheduled: 1)),
          stub(status: stub(currentNumberScheduled: 0, numberMisscheduled: 1)),
          stub(status: stub(currentNumberScheduled: 0, numberMisscheduled: 0))
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        doc.deploy
      end
    end
  end

  describe "#validate_config_file" do
    let(:doc) { kubernetes_release_docs(:test_release_pod_1).dup }

    it "is valid" do
      assert_valid doc
    end

    it "is invalid when missing role" do
      assert doc.raw_template.sub!('role', 'mole')
      refute_valid doc
    end

    it "is invalid when missing project" do
      assert doc.raw_template.sub!('project', 'reject')
      refute_valid doc
    end

    it "is invalid with mismatching project or role" do
      assert doc.raw_template.sub!('project: foobar', 'project: barfoo')
      refute_valid doc
    end

    it "ignores unsupported type" do
      doc.raw_template << "\n" << {'kind' => "Wut"}.to_yaml
      assert_valid doc
    end

    describe "with service" do
      let(:service) { {'kind' => 'Service', 'spec' => {'selector' => {'project' => 'foobar', 'role' => 'app-server'}}} }

      it "is valid" do
        doc.raw_template << "\n" << service.to_yaml
        assert_valid doc
      end

      it "is invalid with different project" do
        service.fetch('spec').fetch('selector')['project'] = 'barfoo'
        doc.raw_template << "\n" << service.to_yaml
        refute_valid doc
      end
    end
  end
end
