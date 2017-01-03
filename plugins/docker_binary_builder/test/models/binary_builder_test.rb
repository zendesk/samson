# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: (defined?(Rake) ? 16 : 14) # during rake it is 16

describe BinaryBuilder do
  run_inside_of_temp_directory

  let(:project) { projects(:test) }
  let(:reference) { 'aBc-19F' }
  let(:output) { StringIO.new }
  let(:executor) { TerminalExecutor.new(output, verbose: true) }
  let(:builder) { BinaryBuilder.new(Dir.pwd, project, reference, output, executor) }

  before do
    GitRepository.any_instance.stubs(valid_url?: true)
    Docker.stubs(:version).returns('ApiVersion' => '1.19')
  end

  describe '#build' do
    let(:fake_image) { stub(remove: true) }
    let(:fake_container) { stub(delete: true, start: true, attach: true, copy: true) }

    before do
      Docker::Container.stubs(:create).returns(fake_container)
      Docker::Util.stubs(:create_relative_dir_tar).returns(nil)
      Docker::Image.stubs(:build_from_tar).returns(fake_image)
      builder.stubs(:untar).returns(true)
      project.update_attributes(docker_release_branch: 'master')
      builder.stubs(:build_file_exist?).returns(true)
    end

    it 'builds the image' do
      executor.expects(:execute!).never

      builder.build
      output.string.must_equal [
        "Connecting to Docker host with Api version: 1.19 ...\n",
        "### Creating tarfile for Docker build\n",
        "### Running Docker build\n",
        "### Docker build complete\n",
        "Now starting Build container...\n",
        "Grabbing '/app/artifacts.tar' from build container...\n",
        "Continuing docker build...\n",
        "Cleaning up docker build image and container...\n"
      ].join
    end

    it 'reports docker errors' do
      fake_container.expects(:attach).raises("Opps")
      assert_raises(Samson::Hooks::UserError) { builder.build }
    end

    it 'does nothing if docker flag is set for project but no dockerfile.build exists' do
      builder.unstub(:build_file_exist?)
      builder.expects(:create_build_image).never
      builder.build
    end

    describe "with pre build shell script" do
      let(:pre_build_script) { BinaryBuilder::PRE_BUILD_SCRIPT }
      before do
        File.write(pre_build_script, 'echo foobar')
        File.chmod(0o755, pre_build_script)
      end

      it 'succeeds when pre build script succeeds' do
        builder.build
        output.string.gsub(/» .*\n/, '').must_equal [
          "Running pre build script...\n",
          "foobar\r\n",
          "Connecting to Docker host with Api version: 1.19 ...\n",
          "### Creating tarfile for Docker build\n",
          "### Running Docker build\n",
          "### Docker build complete\n",
          "Now starting Build container...\n",
          "Grabbing '/app/artifacts.tar' from build container...\n",
          "Continuing docker build...\n",
          "Cleaning up docker build image and container...\n"
        ].join
      end

      it 'stop build when pre build script fails' do
        File.write(pre_build_script, 'oops')
        assert_raises(Samson::Hooks::UserError) { builder.build }
      end
    end
  end

  describe "#create_container_options" do
    it 'uses the old style of mounting directories with api v1.19' do
      Docker.stubs(:version).returns('ApiVersion' => '1.19')
      builder.send(:create_container_options).must_equal(
        'Cmd' => ['/app/build.sh'],
        'Image' => 'foo_build:abc-19f',
        'Env' => [],
        'Volumes' => { '/opt/samson_build_cache' => {} },
        'HostConfig' => {
          'Binds' => ['/opt/samson_build_cache:/build/cache'],
          'NetworkMode' => 'host'
        }
      )
    end

    it 'uses the new style of mounting directories with api v1.20' do
      Docker.stubs(:version).returns('ApiVersion' => '1.24')
      builder.send(:create_container_options).must_equal(
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
      )
    end

    it 'sets up global environment variables for the build container' do
      project.environment_variables.create!(name: 'FIRST', value: 'first')
      project.environment_variables.create!(name: 'SECOND', value: 'second')
      project.environment_variables.create!(
        name: 'THIRD', value: 'third',
        scope_type: 'Environment', scope_id: environments(:production).id
      )
      builder.send(:create_container_options)['Env'].must_equal %w[FIRST=first SECOND=second]
    end

    it 'throws exception with api < 1.15' do
      Docker.stubs(:version).returns('ApiVersion' => '1.14')
      proc { builder.send(:create_container_options) }.must_raise RuntimeError
    end
  end

  describe '#image_name' do
    it 'downcases the image name' do
      image_name = builder.send(:image_name)
      image_name.must_equal(image_name.downcase)
    end

    describe 'with git refs that include slashes' do
      let(:reference) { 'namespaced/ref' }

      it 'replaces slashes with dashes' do
        builder.send(:image_name).must_equal 'foo_build:namespaced-ref'
      end
    end
  end
end
