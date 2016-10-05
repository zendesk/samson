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
  let(:primary_template) { doc.resource_template[0] }
  let(:kube_404) { KubeException.new(404, 2, 3) }
  let(:service_url) { "http://foobar.server/api/v1/namespaces/pod1/services/some-project" }

  before do
    configs = YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))
    configs.each { |c| c['metadata']['namespace'] = 'pod1' }
    doc.send(:resource_template=, configs)
  end

  describe "#store_resource_template" do
    def create!
      Kubernetes::ReleaseDoc.create!(doc.attributes.except('id', 'resource_template'))
    end

    before do
      kubernetes_fake_raw_template
      Kubernetes::ResourceTemplate.any_instance.stubs(:set_image_pull_secrets) # makes an extra request we ignore
    end

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

    it "keeps kube-system namespace because it is a unique system namespace" do
      assert doc.send(:raw_template).
        sub!("name: some-project-rc\n", "name: some-project-rc\n  namespace: kube-system\n")
      create!.resource_template[0][:metadata][:namespace].must_equal 'kube-system'
    end
  end

  describe "#deploy" do
    let(:client) { doc.deploy_group.kubernetes_cluster.extension_client }

    it "creates" do
      # check and then create service
      stub_request(:get, service_url).to_raise(kube_404)
      stub_request(:post, "http://foobar.server/api/v1/namespaces/pod1/services").to_return(body: "{}")

      # check and then create deployment
      client.expects(:get_deployment).raises(kube_404)
      client.expects(:create_deployment).returns(stub(to_hash: {}))

      doc.deploy
      doc.instance_variable_get(:@previous_deploy).must_equal([nil, nil]) # will not revert
    end

    it "remembers the previous deploy in case we have to revert" do
      # check service ... do nothing
      stub_request(:get, service_url).
        to_return(body: '{"SER":"VICE"}')

      # check and update deployment
      client.expects(:get_deployment).returns(DE: "PLOY")
      client.expects(:update_deployment).returns("Rest client resonse")

      doc.deploy
      doc.instance_variable_get(:@previous_deploy).must_equal([{DE: "PLOY"}, {SER: "VICE"}])
    end
  end

  describe '#revert' do
    it "reverts all resources" do
      doc.instance_variable_set(:@previous_deploy, [{DE: "PLOY"}, {SER: "VICE"}])
      doc.instance_variable_set(:@deployed, true)
      doc.send(:resources)[0].expects(:revert).with(DE: "PLOY")
      doc.send(:resources)[1].expects(:revert).with(SER: "VICE")
      doc.revert
    end
  end

  describe "#validate_config_file" do
    let(:doc) { kubernetes_release_docs(:test_release_pod_1).dup } # validate_config_file is always called on a new doc

    before { doc.stubs(raw_template: read_kubernetes_sample_file('kubernetes_deployment.yml')) }

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
      primary_template[:kind] = 'Job'
      doc.desired_pod_count.must_equal 2
    end

    it "asks kubernetes for daemon set since we do not know how many nodes it will match" do
      primary_template[:kind] = 'DaemonSet'
      stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/pod1/daemonsets/some-project-rc").
        to_return(body: {status: {desiredNumberScheduled: 3}}.to_json)
      doc.desired_pod_count.must_equal 3
    end
  end

  describe "#build" do
    it "fetches the build" do
      doc.build.must_equal builds(:docker_build)
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
      kubernetes_fake_raw_template
      doc.verify_template
    end
  end
end
