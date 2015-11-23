require_relative '../../test_helper'

describe Kubernetes::RoleConfigFile do

  describe 'Parsing a valid Kubernetes config file' do
    let(:contents) { parse_role_config_file('kubernetes_role_config_file') }

    let(:config_file) { Kubernetes::RoleConfigFile.new(contents, 'some-file.yml') }

    it 'should load a replication controller with its contents' do
      config_file.replication_controller.wont_be_nil

      # Labels
      config_file.replication_controller.labels[:role].must_equal 'some-role'

      # Replicas
      config_file.replication_controller.replicas.must_equal 2

      # Selector
      config_file.replication_controller.selector[:project].must_equal 'some-project'
      config_file.replication_controller.selector[:role].must_equal 'some-role'

      # Pod Template
      config_file.replication_controller.pod_template.wont_be_nil
      config_file.replication_controller.pod_template.labels.wont_be_nil
      config_file.replication_controller.pod_template.container.wont_be_nil

      # Container
      config_file.replication_controller.pod_template.container.cpu.must_equal '0.5'
      config_file.replication_controller.pod_template.container.ram.must_equal '100'
    end

    it 'should load a service with its contents' do
      config_file.service.wont_be_nil

      # Service Name
      config_file.service.name.must_equal 'some-project'

      # Labels
      config_file.service.labels[:project].must_equal 'some-project'

      # Selector
      config_file.service.selector[:project].must_equal 'some-project'
      config_file.service.selector[:role].must_equal 'some-role'
    end
  end

  describe 'Parsing a Kubernetes with a missing replication controller' do
    let(:contents) { parse_role_config_file('kubernetes_invalid_role_config_file') }

    it 'should raise an exception' do
      assert_raises RuntimeError do
        Kubernetes::RoleConfigFile.new(contents, 'some-file.yml')
      end
    end
  end
end
