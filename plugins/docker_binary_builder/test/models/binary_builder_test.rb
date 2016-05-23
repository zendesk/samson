require_relative '../test_helper'

SingleCov.covered! uncovered: (defined?(Rake) ? 15 : 14) # during rake it is 15

describe BinaryBuilder do
  let(:project) { projects(:test) }
  let(:dir) { '/tmp' }
  let(:reference) { 'aBc-19F' }
  let(:output) { StringIO.new }
  let(:executor) { TerminalExecutor.new(@output_stream, verbose: true) }
  let(:builder) { BinaryBuilder.new(dir, project, reference, output, executor) }

  before do
    GitRepository.any_instance.stubs(valid_url?: true)
    Docker.stubs(:version).returns('ApiVersion' => '1.19')
  end

  describe '#build' do
    let(:fake_image) { stub(remove: true) }
    let(:fake_container) { stub(delete: true, start: true, attach: true, copy: true) }
    let(:pre_build_script) { File.join(dir, BinaryBuilder::PRE_BUILD_SCRIPT) }

    before do
      Docker::Container.stubs(:create).returns(fake_container)
      Docker::Image.stubs(:build_from_dir).returns(fake_image)
      builder.stubs(:untar).returns(true)
      project.update_attributes(deploy_with_docker: true)
      builder.stubs(:build_file_exist?).returns(true)
    end

    it 'builds the image' do
      executor.expects(:execute!).with(pre_build_script).never

      builder.build
      output.string.must_equal [
        "Connecting to Docker host with Api version: 1.19 ...\n",
        "Now building the build container...\n",
        "Now starting Build container...\n",
        "Grabbing '/app/artifacts.tar' from build container...\n",
        "Continuing docker build...\n",
        "Cleaning up docker build image and container...\n"
      ].join
    end

    it 'does nothing if docker flag is not set for project' do
      project.update_attributes(deploy_with_docker: false)
      builder.expects(:create_build_image).never
      builder.build
    end

    it 'does nothing if docker flag is set for project but no dockerfile.build exists' do
      builder.unstub(:build_file_exist?)
      builder.expects(:create_build_image).never
      builder.build
    end

    describe "with pre build shell script" do
      before { builder.expects(:pre_build_file_exist?).returns(true) }

      it 'run pre build shell script if it is available' do
        executor.expects(:execute!).with(pre_build_script).returns(true)

        builder.build
        output.string.must_equal [
          "Running pre build script...\n",
          "Connecting to Docker host with Api version: 1.19 ...\n",
          "Now building the build container...\n",
          "Now starting Build container...\n",
          "Grabbing '/app/artifacts.tar' from build container...\n",
          "Continuing docker build...\n",
          "Cleaning up docker build image and container...\n"
        ].join
      end

      it 'stop build when pre build shell script fails' do
        executor.expects(:execute!).with(pre_build_script).returns(false)

        assert_raises RuntimeError do
          builder.build
        end
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
  end
end
