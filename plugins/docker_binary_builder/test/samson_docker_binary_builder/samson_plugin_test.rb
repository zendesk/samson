require_relative '../test_helper'

SingleCov.covered! uncovered: 2 unless defined?(Rake) # rake preloads all plugins

describe SamsonDockerBinaryBuilder do
  describe '#after_deploy_setup' do
    let(:admin) { users(:admin) }
    let(:stage) { stages(:test_production) }
    let(:deploy) { stage.create_deploy(admin, reference: 'reference') }
    let(:dir) { '/tmp' }
    let(:output) { StringIO.new }

    before do
      BinaryBuilder.any_instance.stubs(:build).returns(true)
    end

    it 'does nothing if stage has docker_binary_plugin_enabled disabled' do
      deploy.stage[:docker_binary_plugin_enabled] = false
      BinaryBuilder.any_instance.expects(:build).never
      Samson::Hooks.fire(:after_deploy_setup, dir, deploy.job, output, deploy.reference)
      output.string.must_equal "Skipping binary build phase!\n"
    end

    it 'kicks off the docker build after_deploy_setup is fired' do
      deploy.stage[:docker_binary_plugin_enabled] = true
      BinaryBuilder.any_instance.expects(:build).once
      Samson::Hooks.fire(:after_deploy_setup, dir, deploy.job, output, deploy.reference)
      output.string.must_equal ''
    end
  end
end
