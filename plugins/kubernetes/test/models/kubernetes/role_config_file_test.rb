require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RoleConfigFile do
  let(:contents) { read_kubernetes_sample_file('kubernetes_role_config_file.yml') }
  let(:config_file) { Kubernetes::RoleConfigFile.new(contents, 'some-file.yml') }

  describe "#deployment" do
    it 'loads a deployment with its contents' do
      config_file.deployment.wont_be_nil

      # Labels
      config_file.deployment.metadata.labels.role.must_equal 'some-role'

      # Replicas
      config_file.deployment.spec.replicas.must_equal 2

      # Selector
      config_file.deployment.spec.selector.matchLabels.project.must_equal 'some-project'
      config_file.deployment.spec.selector.matchLabels.role.must_equal 'some-role'

      # Pod Template
      config_file.deployment.spec.template.metadata.name.must_equal 'some-project-pod'
      config_file.deployment.spec.template.metadata.labels.project.must_equal 'some-project'
      config_file.deployment.spec.template.metadata.labels.role.must_equal 'some-role'
    end

    it "parses a Daemonset" do
      assert contents.sub!('Deployment', 'DaemonSet')
      config_file.deployment.spec.replicas.must_equal 2
    end

    # TODO: maybe make this consistent and move the raise outside ...
    it "raises when no deployment is found" do
      assert contents.sub!('Deployment', 'SomethingElse')
      e = assert_raises RuntimeError do
        config_file.deployment
      end
      e.message.must_include 'Deployment specification missing in the configuration file'
    end

    it 'tells which file failed when there is an error' do
      Rails.logger.expects(:error).with { |m| m.must_include 'some-file.yml'; true }
      Kubernetes::RoleConfigFile::Deployment.expects(:new).raises
      assert_raises(RuntimeError) { config_file.deployment }
    end

    describe "#strategy_type" do
      it "defaults" do
        config_file.deployment.strategy_type.must_equal 'RollingUpdate'
      end

      it "uses the set value" do
        assert contents.sub!('spec:', "spec:\n  strategy:\n    type: Foobar")
        config_file.deployment.strategy_type.must_equal 'Foobar'
      end
    end
  end

  describe "#service" do
    it 'loads a service with its contents' do
      config_file.service.wont_be_nil

      # Service Name
      config_file.service.metadata.name.must_equal 'some-project'

      # Labels
      config_file.service.metadata.labels.project.must_equal 'some-project'

      # Selector
      config_file.service.spec.selector.project.must_equal 'some-project'
      config_file.service.spec.selector.role.must_equal 'some-role'
    end

    it 'is nil when no service is found' do
      assert contents.sub!('Service', 'SomethingElse')
      config_file.service.must_equal nil
    end

    it 'tells which file failed when there is an error' do
      Rails.logger.expects(:error).with { |m| m.must_include 'some-file.yml'; true }
      Kubernetes::RoleConfigFile::Service.expects(:new).raises
      assert_raises(RuntimeError) { config_file.service }
    end
  end

  describe "#job" do
    before { assert contents.sub!('Service', 'Job') }

    it 'loads a job' do
      assert config_file.job
    end

    it 'fails when there is no job' do
      assert contents.sub!('Job', 'NoJob')
      assert_raises(RuntimeError) { config_file.job }
    end

    it 'tells which file failed when there is an error' do
      Rails.logger.expects(:error).with { |m| m.must_include 'some-file.yml'; true }
      Kubernetes::RoleConfigFile::Job.expects(:new).raises
      assert_raises(RuntimeError) { config_file.job }
    end
  end
end
