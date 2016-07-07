require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ReleaseDoc do
  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }

  before do
    kubernetes_fake_raw_template
    doc.resource_template =
      YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))[0]
    doc.resource_template['metadata']['namespace'] = 'pod1'
  end

  describe "#store_resource_template" do
    it "stores the template when creating" do
      created = Kubernetes::ReleaseDoc.create!(doc.attributes.except('id', 'resource_template'))
      created.resource_template['kind'].must_equal 'Deployment'
    end

    it "fails to create with missing config file" do
      Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
      GitRepository.any_instance.expects(:file_content).returns(nil) # File not found
      created = Kubernetes::ReleaseDoc.create(doc.attributes.except('id', 'resource_template'))
      refute created.id
    end
  end

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
        e.message.must_equal "Service name for role app-server was generated and needs to be changed before deploying."
      end

      it "fails when service is required by the role, but not defined" do
        assert doc.raw_template.sub!(/\n---\n.*/m, '')
        e = assert_raises Samson::Hooks::UserError do
          doc.ensure_service
        end
        e.message.must_equal "Unable to find Service definition in kubernetes/app_server.yml"
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
        doc.resource_template['kind'] = 'DaemonSet'
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
      before do
        doc.resource_template['kind'] = 'Job'
      end

      it "creates when job does not exist" do
        client.expects(:get_job).raises(KubeException.new(1, 2, 3))
        client.expects(:create_job)
        doc.deploy
      end

      it "deletes and then creates when job exists" do
        client.expects(:get_job).returns true
        client.expects(:delete_job).with('test-app-server', 'pod1')
        client.expects(:create_job)
        doc.deploy
      end
    end

    it "raises on unknown" do
      doc.resource_template = {'kind' => 'WTFBBQ'}
      e = assert_raises(RuntimeError) { doc.deploy }
      e.message.must_include "Unknown deploy object WTFBBQ"
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

    it "reports detailed errors when invalid" do
      assert doc.raw_template.sub!('role', 'mole')
      refute_valid doc
    end
  end

  describe "#desired_pod_count" do
    it "uses local value for deployment" do
      doc.desired_pod_count.must_equal 2
    end

    it "uses local value for job" do
      doc.resource_template['kind'] = 'Job'
      doc.desired_pod_count.must_equal 2
    end

    it "asks kubernetes for daemon set since we do not know how many nodes it will match" do
      doc.resource_template['kind'] = 'DaemonSet'
      stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/daemonsets/test-app-server").
        to_return(body: {status: {desiredNumberScheduled: 3}}.to_json)
      doc.desired_pod_count.must_equal 3
    end

    it "fails for unknown" do
      doc.resource_template['kind'] = 'Funky'
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
    it "finds deploy" do
      doc.expects(:raw_template).returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))
      doc.deploy_template[:kind].must_equal 'Deployment'
    end

    it "finds job" do
      doc.expects(:raw_template).returns(read_kubernetes_sample_file('kubernetes_job.yml'))
      doc.deploy_template[:kind].must_equal 'Job'
    end
  end

  describe "#job?" do
    it "is a job when it is a job" do
      doc.resource_template = YAML.load(read_kubernetes_sample_file('kubernetes_job.yml'))
      assert doc.job?
    end

    it "is not a job when it is not a job" do
      refute doc.job?
    end
  end
end
