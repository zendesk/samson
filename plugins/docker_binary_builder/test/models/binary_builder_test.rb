require_relative '../test_helper'

describe BinaryBuilder do
  describe '#build' do
    let(:project) { projects(:test) }
    let(:dir) { '/tmp' }
    let(:reference) { 'aBc-19F' }
    let(:output) { StringIO.new }
    let(:builder) { BinaryBuilder.new(dir, project, reference, output) }
    let(:fake_image) { stub(remove: true) }
    let(:fake_container) { stub(delete: true, start: true, attach: true, copy: true) }

    before do
      Docker.stubs(:version).returns({ 'ApiVersion' => '1.19' })
      Docker::Container.stubs(:create).returns(fake_container)
      Docker::Image.stubs(:build_from_dir).returns(fake_image)
      builder.stubs(:untar).returns(true)
    end

    it 'does nothing if docker flag is not set for project' do
      builder.expects(:create_build_image).never
      builder.build
    end

    it 'does nothing if docker flag is set for project but no dockerfile.build exists' do
      File.expects(:exists?).with(File.join(dir, BinaryBuilder::DOCKER_BUILD_FILE)).returns(false)
      project.update_attributes(deploy_with_docker: true)
      builder.expects(:create_build_image).never
      builder.build
    end

    it 'builds image if docker flag is set for project and dockerfile.build exists' do
      File.expects(:exists?).with(File.join(dir, BinaryBuilder::DOCKER_BUILD_FILE)).returns(true)
      project.update_attributes(deploy_with_docker: true)
      builder.build
      output.string.must_equal [
        "Connecting to Docker host with Api version: 1.19 ...\n",
        "Now building the build container...\n",
        "Now starting Build container...\n",
        "Grabbing '/app/artifacts.tar' from build container...\n",
        "Continuing docker build...\n",
        "Cleaning up docker build image and container...\n"].join
    end

    it 'uses the old style of mounting directories with api v1.19' do
      Docker.stubs(:version).returns({ 'ApiVersion' => '1.19' })
      builder.send(:create_container_options).must_equal(
        {
          'Cmd' => ['/app/build.sh'],
          'Image' => 'foo_build:abc-19f',
          'Env' => [],
          'Volumes' => { '/opt/samson_build_cache' => {} },
          'HostConfig' => {
            'Binds' => ['/opt/samson_build_cache:/build/cache'],
            'NetworkMode' => 'host'
          }
        }
      )
    end

    it 'uses the new style of mounting directories with api v1.20' do
      Docker.stubs(:version).returns({ 'ApiVersion' => '1.24' })
      builder.send(:create_container_options).must_equal(
        {
          'Cmd' => ['/app/build.sh'],
          'Image' => 'foo_build:abc-19f',
          'Env' => [],
          'Mounts' => [
            {
              'Source' => '/opt/samson_build_cache',
              'Destination' => '/build/cache',
              'Mode' => 'rw,Z',
              'RW' => true
            }
          ],
          'HostConfig' => {
            'NetworkMode' => 'host'
          }
        }
      )
    end

    it 'sets up global environment variables for the build container' do
      project.environment_variables.create!(name: 'FIRST', value: 'first')
      project.environment_variables.create!(name: 'SECOND', value: 'second')
      project.environment_variables.create!(name: 'THIRD', value: 'third',
                                            scope_type: 'Environment', scope_id: environments(:production).id)
      builder.send(:create_container_options)['Env'].must_equal %w(FIRST=first SECOND=second)
    end

    it 'throws exception with api < 1.15' do
      Docker.stubs(:version).returns({ 'ApiVersion' => '1.14' })
      proc { builder.send(:create_container_options) }.must_raise RuntimeError
    end

    it 'downcases the image name' do
      image_name = builder.send(:image_name)
      image_name.must_equal(image_name.downcase)
    end
  end
end
