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
    kubernetes_fake_raw_template
    configs = YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))
    doc.send(:resource_template=, configs)
    primary_resource[:metadata][:namespace] = 'pod1'
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
      Kubernetes::Service.any_instance.stubs(running?: true)
      doc.ensure_service.must_equal "Service already running"
    end

    it "creates the service when it does not exist" do
      Kubernetes::Service.any_instance.stubs(running?: false)
      doc.deploy_group.kubernetes_cluster.expects(:client).returns(stub(create_service: nil))
      doc.ensure_service.must_equal "Service created"
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
        client.expects(:get_deployment).returns deployment_stub(3)
        client.expects(:update_deployment)
        doc.deploy
      end
    end

    describe "daemonset" do
      before do
        primary_resource[:kind] = 'DaemonSet'
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
          daemonset_stub(0, 0), # initial check
          daemonset_stub(0, 0)  # check for running
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        doc.deploy
      end

      it "deletes and created when daemonset exists with pods" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(4).returns(
          daemonset_stub(0, 0), # initial check
          daemonset_stub(1, 1),
          daemonset_stub(0, 1),
          daemonset_stub(0, 0)
        )
        client.expects(:delete_daemon_set)
        client.expects(:create_daemon_set)
        doc.deploy
      end

      it "tells the user what is wrong when the pods never get terminated" do
        client.expects(:update_daemon_set)
        client.expects(:get_daemon_set).times(31).returns(daemonset_stub(0, 1))
        client.expects(:delete_daemon_set).never
        client.expects(:create_daemon_set).never
        e = assert_raises Samson::Hooks::UserError do
          doc.deploy
        end
        e.message.must_include "misscheduled"
      end
    end

    describe "job" do
      before do
        primary_resource[:kind] = 'Job'
      end

      it "creates when job does not exist" do
        client.expects(:get_job).raises(KubeException.new(1, 2, 3))
        client.expects(:create_job)
        doc.deploy
      end

      it "deletes and then creates when job exists" do
        client.expects(:get_job).returns({})
        client.expects(:delete_job).with('some-project-rc', 'pod1')
        client.expects(:create_job)
        doc.deploy
      end
    end

    it "raises on unknown" do
      doc.stubs(job?: false, deployment?: false, daemonset?: false, fetch_resource: nil)
      e = assert_raises(RuntimeError) { doc.deploy }
      e.message.must_equal "Unsupported resource kind Deployment"
    end
  end

  describe '#revert' do
    let(:client) { doc.send(:extension_client) }

    describe "deployment" do
      before do
        primary_resource[:kind] = 'Deployment'
        doc.instance_variable_set(:'@deployed', true)
        doc.instance_variable_set(:'@new_deploy', deployment_stub(3).to_hash)
      end

      it "is deleted when it's a new deployment" do
        client.expects(:update_deployment)
        client.expects(:get_deployment).times(3).returns(
          deployment_stub(3),
          deployment_stub(3),
          deployment_stub(0)
        )
        client.expects(:delete_deployment)
        doc.revert
      end

      it "rolls back when a deployment already existed" do
        doc.instance_variable_set(:'@previous_deploy', deployment_stub(3).to_hash)

        client.expects(:rollback_deployment)
        doc.revert
      end
    end

    # I really don't like these unit tests, since it's doing all sorts of
    # mocking and mucking of internal state. But I don't know of a better
    # way to test the functionality.  :-(
    describe "daemonset" do
      before do
        primary_resource[:kind] = 'DaemonSet'
        doc.instance_variable_set(:'@deployed', true)
        doc.instance_variable_set(:'@new_deploy', daemonset_stub(3, 0).to_hash)
      end

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
        doc.instance_variable_set(:'@previous_deploy', daemonset_stub(3, 0))

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
        doc.instance_variable_set(:'@deployed', true)
      end

      it "is deleted" do
        client.expects(:delete_job)
        doc.revert
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
      assert doc.raw_template.sub!('role', 'mole')
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

    it "fails for unknown" do
      assert_raises RuntimeError do
        doc.stubs(job?: false, deployment?: false, daemonset?: false)
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
