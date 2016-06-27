require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ReleaseDoc do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }

  before { kubernetes_fake_raw_template }

  describe "#ensure_service" do
    it "does nothing when no service is defined" do
      doc.ensure_service.must_equal "no Service defined"
    end

    it "does nothing when no service is running" do
      doc.kubernetes_role.service_name = 'app'
      Kubernetes::Service.any_instance.stubs(running?: true)
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
        e.message.must_equal "Config file kubernetes/app_server.yml included 0 objects of kind Service, 1 is supported"
      end

      it "fails when multiple services are defined and we would only ensure the first one" do
        doc.raw_template << "\n" << {'kind' => 'Service'}.to_yaml

        e = assert_raises Samson::Hooks::UserError do
          doc.ensure_service
        end
        e.message.must_equal "Config file kubernetes/app_server.yml included 2 objects of kind Service, 1 is supported"
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
        doc.send(:deploy_yaml).send(:template)['kind'] = 'DaemonSet'
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

    describe "job" do
      before { doc.send(:deploy_yaml).send(:template)['kind'] = 'Job' }

      it "creates when job does not exist" do
        client.expects(:get_job).raises(KubeException.new(1, 2, 3))
        client.expects(:create_job)
        doc.deploy
      end

      it "deletes and then creates when job exists" do
        client.expects(:get_job).returns true
        client.expects(:delete_job).with('test', 'pod1')
        client.expects(:create_job)
        doc.deploy
      end
    end

    it "raises on unknown" do
      doc.send(:deploy_yaml).send(:template)['kind'] = 'WTFBBQ'
      e = assert_raises(RuntimeError) { doc.deploy }
      e.message.must_include "Unknown deploy object wtfbbq"
    end
  end

  describe "#validate_config_file" do
    let(:doc) { kubernetes_release_docs(:test_release_pod_1).dup }

    it "is valid" do
      assert_valid doc
    end

    it "is invalid without template" do
      doc.stubs(raw_template: nil)
      refute_valid doc
      doc.errors.full_messages.must_equal(
        ["Kubernetes release does not contain config file 'kubernetes/app_server.yml'"]
      )
    end

    it "is invalid when missing role" do
      assert doc.raw_template.sub!('role', 'mole')
      refute_valid doc
    end

    it "ignores unsupported type" do
      doc.raw_template << "\n" << {'kind' => "Wut", 'metadata' => {'name' => 'test'}}.to_yaml
      assert_valid doc
    end
  end

  describe "#desired_pod_count" do
    it "uses local value for deployment" do
      doc.desired_pod_count.must_equal 2
    end

    it "uses local value for job" do
      doc.send(:deploy_yaml).send(:template)[:kind] = 'Job'
      doc.desired_pod_count.must_equal 2
    end

    it "asks kubernetes for daemon set since we do not know how many nodes it will match" do
      doc.send(:deploy_yaml).send(:template)[:kind] = 'DaemonSet'
      stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/daemonsets/test").
        to_return(body: {status: {desiredNumberScheduled: 3}}.to_json)
      doc.desired_pod_count.must_equal 3
    end

    it "fails for unknown" do
      doc.send(:deploy_yaml).send(:template)[:kind] = 'Funky'
      assert_raises RuntimeError do
        doc.desired_pod_count
      end
    end
  end

  describe "#client" do
    it "builds a client" do
      assert doc.client
    end
  end

  describe "#build" do
    it "fetches the build" do
      doc.build.must_equal builds(:docker_build)
    end
  end

  describe "#raw_template" do
    before do
      Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
      GitRepository.any_instance.expects(:file_content).
        with('kubernetes/app_server.yml', doc.kubernetes_release.git_sha).
        returns("xxx")
    end

    it "fetches the template from git" do
      doc.raw_template.must_equal "xxx"
    end

    it "caches" do
      doc.raw_template.object_id.must_equal doc.raw_template.object_id
    end

    it "caches not found templates" do
      GitRepository.any_instance.unstub(:file_content)
      GitRepository.any_instance.expects(:file_content).once.returns(nil)
      doc.raw_template.must_equal nil
      doc.raw_template.must_equal nil
    end
  end

  describe "#deploy_template" do
    let(:raw_template) { "---\nkind: Deployment\n" }
    let(:service) { "---\nkind: Service\n" }

    before { doc.expects(:raw_template).returns(raw_template) }

    it "works with 1 deploy object" do
      doc.deploy_template.must_equal("kind" => 'Deployment')
    end

    it "ignores non-deploy objects" do
      raw_template.prepend service
      doc.deploy_template.must_equal("kind" => 'Deployment')
    end
  end

  describe "#job?" do
    it "is a job when it is a job" do
      assert doc.raw_template.sub!('Deployment', 'Job')
      assert doc.job?
    end

    it "is not a job when it is not a job" do
      refute doc.job?
    end
  end
end
