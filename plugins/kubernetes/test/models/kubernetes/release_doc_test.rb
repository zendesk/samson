# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::ReleaseDoc do
  def deployment_stub(replica_count)
    stub(
      "Deployment stub",
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
      "DaemonSet stub",
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
      doc.kubernetes_release.builds = [builds(:docker_build)]
      Kubernetes::ReleaseDoc.create!(
        doc.attributes.except('id', 'resource_template').merge(kubernetes_release: doc.kubernetes_release)
      )
    end

    before do
      kubernetes_fake_raw_template
      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets) # makes an extra request we ignore
    end

    it "stores the template when creating" do
      create!.resource_template[0][:kind].must_equal 'Deployment'
    end

    it "fails to create with missing config file" do
      Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
      GitRepository.any_instance.expects(:file_content).returns(nil) # File not found
      assert_raises(ActiveRecord::RecordInvalid) { create! }
    end

    it "adds counter to service names when using multiple services" do
      doc.kubernetes_role.update_column(:service_name, 'foo')
      template = Kubernetes::ReleaseDoc.new.send(:raw_template) # stubs makes all docs share the same template
      template.push template[1].deep_dup # 2 Services
      create!.resource_template[1][:metadata][:name].must_equal 'foo'
      create!.resource_template[2][:metadata][:name].must_equal 'foo-2'
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
      doc.instance_variable_get(:@previous_resources).must_equal([nil, nil]) # will not revert
    end

    it "remembers the previous deploy in case we have to revert" do
      # check service ... do nothing
      stub_request(:get, service_url).to_return(body: '{"SER":"VICE"}')
      stub_request(:put, service_url)

      # check and update deployment
      client.expects(:get_deployment).returns({DE: "PLOY"}.to_json)
      client.expects(:update_deployment).returns("Rest client resonse")

      doc.deploy
      doc.instance_variable_get(:@previous_resources).must_equal([{DE: "PLOY"}, {SER: "VICE"}])
    end
  end

  describe '#revert' do
    it "reverts all resources" do
      doc.instance_variable_set(:@previous_resources, [{DE: "PLOY"}, {SER: "VICE"}])
      doc.send(:resources)[0].expects(:revert).with(DE: "PLOY")
      doc.send(:resources)[1].expects(:revert).with(SER: "VICE")
      doc.revert
    end
  end

  describe "#validate_config_file" do
    let(:doc) { kubernetes_release_docs(:test_release_pod_1).dup } # validate_config_file is always called on a new doc

    it "is valid" do
      kubernetes_fake_raw_template
      assert_valid doc
    end

    it "is invalid without template" do
      GitRepository.any_instance.expects(:file_content).returns(nil)
      refute_valid doc
      doc.errors.full_messages.must_equal(
        ["Kubernetes release does not contain config file 'kubernetes/app_server.yml'"]
      )
    end

    it "reports detailed errors when invalid" do
      GitRepository.any_instance.expects(:file_content).returns("foo: bar")
      refute_valid doc
    end
  end

  describe "#desired_pod_count" do
    it "delegates to primary resource" do
      doc.desired_pod_count.must_equal 2
    end
  end

  describe "#prerequisite?" do
    it "delegates to primary resource" do
      refute doc.prerequisite?
    end
  end

  # tested in depth from deploy_executor.rb since it has to work when called with it's local ReleaseDoc setup
  describe "#verify_template" do
    it "can run with a new release doc" do
      kubernetes_fake_raw_template
      doc.verify_template
    end
  end

  describe "#blue_green_color" do
    before { doc.kubernetes_release.blue_green_color = "green" }

    it "is releases color when blue-green" do
      doc.kubernetes_role.blue_green = true
      assert doc.blue_green_color.must_equal "green"
    end

    it "is nil when not blue-green" do
      refute doc.blue_green_color
    end
  end
end
