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

  describe "#primary" do
    it 'finds a Deployment' do
      config_file.primary[:kind].must_equal 'Deployment'
    end

    it "finds a Daemonset" do
      assert content.sub!('Deployment', 'DaemonSet')
      assert content.sub!(/\n---.*/m, '')
      config_file.primary[:kind].must_equal 'DaemonSet'
    end

    it "blows up on unsupported" do
      assert content.sub!('Service', 'Deployment')
      assert_raises(Samson::Hooks::UserError) { config_file }
    end

    it "allows deep symbol access" do
      config_file.primary.fetch(:spec).fetch(:selector).fetch(:matchLabels).fetch(:project).must_equal 'some-project'
    end
  end

  describe "#services" do
    it 'loads a service with its content' do
      config_file.services[0][:kind].must_equal 'Service'
    end

    it 'is empty when no service is found' do
      content.replace(read_kubernetes_sample_file('kubernetes_job.yml'))
      config_file.services.must_equal []
    end
  end
end
