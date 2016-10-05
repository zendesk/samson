# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ReleaseDoc do
  def deployment_stub(replica_count)
    stub(
      to_hash: {
        spec: {
          'replicas=' => replica_count
        },
        status: {
          replicas: replica_count
        }
      }
    )
  end

  def daemonset_stub(scheduled, misscheduled)
    stub(
      to_hash: {
        kind: "DaemonSet",
        metadata: {
          name: 'some-project',
          namespace: 'pod1'
        },
        status: {
          currentNumberScheduled: scheduled,
          numberMisscheduled:     misscheduled
        },
        spec: {
          template: {
            spec: {
              'nodeSelector=' => nil
            }
          }
        }
      }
    )
  end

  let(:doc) { kubernetes_release_docs(:test_release_pod_1) }
  let(:primary_resource) { doc.resource_template[0] }

  before do
    kubernetes_fake_raw_template # TODO: this is only needed by very few tests ...
    configs = YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))
    configs.each { |c| c['metadata']['namespace'] = 'pod1' }
    doc.send(:resource_template=, configs)
  end

  describe "#store_resource_template" do
    def create!
      Kubernetes::ReleaseDoc.create!(doc.attributes.except('id', 'resource_template'))
    end

    before { Kubernetes::ResourceTemplate.any_instance.stubs(:set_image_pull_secrets) }

    it "stores the template when creating" do
      create!.resource_template[0][:kind].must_equal 'Deployment'
    end

    it "does not store blank service name" do
      doc.kubernetes_role.update_column(:service_name, '') # user left field empty
      create!.resource_template[1][:metadata][:name].must_equal 'some-project'
    end

    it "fails to create with missing config file" do
      Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
      GitRepository.any_instance.expects(:file_content).returns(nil) # File not found
      assert_raises(ActiveRecord::RecordInvalid) { create! }
    end

    it "fails when trying to create for a generated service" do
      doc.kubernetes_role.update_column(:service_name, "app-server#{Kubernetes::Role::GENERATED}1211212")
      e = assert_raises Samson::Hooks::UserError do
        create!
      end
      e.message.must_equal "Service name for role app-server was generated and needs to be changed before deploying."
    end
  end

  describe "#ensure_service" do
    it "does nothing when no service is not defined" do
      doc.resource_template.pop
      doc.ensure_service.must_equal "Service not defined"
    end

    it "does nothing when no service is running" do
      Kubernetes::Resource::Service.any_instance.stubs(running?: true)
      doc.ensure_service.must_equal "Service already running"
    end

    it "creates the service when it does not exist" do
      Kubernetes::Resource::Service.any_instance.stubs(running?: false)
      doc.deploy_group.kubernetes_cluster.expects(:client).returns(stub(create_service: nil))
      doc.ensure_service.must_equal "Service created"
    end
  end

  describe "#deploy" do
    let(:client) { doc.send(:extension_client) }

    it "creates" do
      client.expects(:get_deployment).raises(KubeException.new(404, 2, 3))
      client.expects(:create_deployment).returns(stub(to_hash: {}))
      doc.deploy
      refute doc.instance_variable_get(:@previous_deploy) # will not revert
    end

    it "remembers the previous deploy in case we have to revert" do
      client.expects(:get_deployment).returns(foo: :bar)
      client.expects(:update_deployment).returns("Rest client resonse")
      doc.deploy
      doc.instance_variable_get(:@previous_deploy).must_equal(foo: :bar)
    end
  end

  describe '#revert' do
    let(:client) { doc.send(:extension_client) }
    let(:service_url) { "http://foobar.server/api/v1/namespaces/pod1/services/some-project" }

    before do
      doc.instance_variable_set(:@deployed, true)
      stub_request(:get, service_url).to_return(status: 404)
    end

    describe "deployment" do
      before do
        primary_resource[:kind] = 'Deployment'
      end

      it "is deleted when it's a new deployment" do
        doc.send(:resource_object).expects(:delete)
        doc.revert
      end

      it "rolls back when a deployment already existed" do
        doc.instance_variable_set(:@previous_deploy, deployment_stub(3).to_hash)

        client.expects(:rollback_deployment)
        doc.revert
      end
    end

    # I really don't like these unit tests, since it's doing all sorts of
    # mocking and mucking of internal state. But I don't know of a better
    # way to test the functionality.  :-(
    describe "daemonset" do
      before { primary_resource[:kind] = 'DaemonSet' }

      it "is deleted when it's brand new" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(2).returns(
          daemonset_stub(3, 0),
          daemonset_stub(0, 0)
        )
        client.expects(:delete_daemon_set)

        doc.revert
      end

      it "is deleted and recreated on rollback" do
        doc.instance_variable_set(:@previous_deploy, daemonset_stub(3, 0).to_hash)

        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(2).returns(
          daemonset_stub(3, 0), # Deleting old
          daemonset_stub(0, 0), # Old deleted
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)

        doc.revert
      end
    end

    describe 'job' do
      before do
        primary_resource[:kind] = 'Job'
      end

      it "is deleted" do
        client.expects(:delete_job)
        doc.revert
      end
    end

    describe 'service' do
      before do
        stub_request(:get, service_url).to_return(body: "{}")
      end

      it "does nothing when there is a service but it is old" do
        client.stubs(:rollback_deployment) # deploy is reverted

        doc.instance_variable_set(:@previous_deploy, daemonset_stub(3, 0).to_hash)
        doc.revert
      end

      it "deletes the service when there is no previous deploy" do
        doc.send(:resource_object).expects(:delete) # deploy is deleted

        delete = stub_request(:delete, service_url)
        doc.revert
        assert_requested delete
      end
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
      assert doc.send(:raw_template).sub!('role', 'mole')
      refute_valid doc
    end
  end

  describe "#desired_pod_count" do
    it "uses local value for deployment" do
      doc.desired_pod_count.must_equal 2
    end

    it "uses local value for job" do
      primary_resource[:kind] = 'Job'
      doc.desired_pod_count.must_equal 2
    end

    it "asks kubernetes for daemon set since we do not know how many nodes it will match" do
      primary_resource[:kind] = 'DaemonSet'
      stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/daemonsets/some-project-rc").
        to_return(body: {status: {desiredNumberScheduled: 3}}.to_json)
      doc.desired_pod_count.must_equal 3
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
      doc.send(:raw_template).must_equal "xxx"
    end

    it "caches" do
      doc.send(:raw_template).object_id.must_equal doc.send(:raw_template).object_id
    end

    it "caches not found templates" do
      GitRepository.any_instance.unstub(:file_content)
      GitRepository.any_instance.expects(:file_content).once.returns(nil)
      doc.send(:raw_template).must_equal nil
      doc.send(:raw_template).must_equal nil
    end
  end

  describe "#job?" do
    it "is a job when it is a job" do
      doc.send(:resource_template=, YAML.load_stream(read_kubernetes_sample_file('kubernetes_job.yml')))
      assert doc.job?
    end

    it "is not a job when it is not a job" do
      refute doc.job?
    end
  end

  # tested in depth from deploy_executor.rb
  describe "#verify_template" do
    it "can run with a new release doc" do
      doc.verify_template
    end
  end
end
