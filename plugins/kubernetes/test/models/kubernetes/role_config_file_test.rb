require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RoleConfigFile do
  let(:content) { read_kubernetes_sample_file('kubernetes_role_config_file.yml') }
  let(:config_file) { Kubernetes::RoleConfigFile.new(content, 'some-file.yml') }

  describe "#initialize" do
    it "fails with a message that points to the broken file" do
      e = assert_raises Samson::Hooks::UserError do
        Kubernetes::RoleConfigFile.new(content, 'some-file.json')
      end
      e.message.must_include 'some-file.json'
    end
  end

  describe "#deploy" do
    it 'finds a Deployment' do
      config_file.deploy[:kind].must_equal 'Deployment'
    end

    it "finds a Daemonset" do
      assert content.sub!('Deployment', 'DaemonSet')
      config_file.deploy[:kind].must_equal 'DaemonSet'
    end

    it "ignores others" do
      assert content.sub!('Deployment', 'SomethingElse')
      config_file.deploy.must_equal nil
    end

    # general purpose assertions that also apply to all other types
    it "passes when required and there" do
      config_file.deploy(required: true)[:kind].must_equal 'Deployment'
    end

    it "fails when required and not there" do
      assert content.sub!('Deployment', 'SomethingElse')
      e = assert_raises Samson::Hooks::UserError do
        config_file.deploy(required: true)
      end
      e.message.must_equal(
        "Config file some-file.yml included 0 objects of kind Deployment or DaemonSet, 1 is supported"
      )
    end

    it "allows deep symbol access" do
      config_file.deploy.fetch(:spec).fetch(:selector).fetch(:matchLabels).fetch(:project).must_equal 'some-project'
    end

    it "fails when there are multiple, which would be unsupported" do
      assert content.sub!('Service', 'DaemonSet')
      e = assert_raises Samson::Hooks::UserError do
        config_file.deploy
      end
      e.message.must_equal(
        "Config file some-file.yml included 2 objects of kind Deployment or DaemonSet, 1 or none are supported"
      )
    end
  end

  describe "#service" do
    it 'loads a service with its content' do
      config_file.service[:kind].must_equal 'Service'
    end

    it 'is nil when no service is found' do
      assert content.sub!('Service', 'SomethingElse')
      config_file.service.must_equal nil
    end
  end

  describe "#job" do
    before { assert content.sub!('Service', 'Job') }

    it 'loads a job' do
      config_file.job[:kind].must_equal 'Job'
    end

    it 'is nil when no job is found' do
      assert content.sub!('Job', 'Service')
      config_file.job.must_equal nil
    end
  end
end
