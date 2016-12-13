# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::RoleConfigFile do
  let(:content) { read_kubernetes_sample_file('kubernetes_deployment.yml') }
  let(:config_file) { Kubernetes::RoleConfigFile.new(content, 'some-file.yml') }

  describe "#initialize" do
    it "fails with a message that points to the broken file" do
      e = assert_raises Samson::Hooks::UserError do
        Kubernetes::RoleConfigFile.new(content, 'some-file.json')
      end
      e.message.must_include 'some-file.json'
    end

    it "fails when empty" do
      e = assert_raises Samson::Hooks::UserError do
        Kubernetes::RoleConfigFile.new("", 'some-file.json')
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
      assert content.sub!(/\n---.*/m, '')
      config_file.deploy[:kind].must_equal 'DaemonSet'
    end

    it "blows up on unsupported" do
      assert content.sub!('Deployment', 'SomethingElse')
      assert_raises(Samson::Hooks::UserError) { config_file }
    end

    it "allows deep symbol access" do
      config_file.deploy.fetch(:spec).fetch(:selector).fetch(:matchLabels).fetch(:project).must_equal 'some-project'
    end
  end

  describe "#service" do
    it 'loads a service with its content' do
      config_file.service[:kind].must_equal 'Service'
    end

    it 'is nil when no service is found' do
      content.replace(read_kubernetes_sample_file('kubernetes_job.yml'))
      config_file.service.must_be_nil
    end
  end

  describe "#job" do
    it 'loads a job' do
      content.replace(read_kubernetes_sample_file('kubernetes_job.yml'))
      config_file.job[:kind].must_equal 'Job'
    end

    it 'is nil when no job is found' do
      config_file.job.must_be_nil
    end
  end
end
