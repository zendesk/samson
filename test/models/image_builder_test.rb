# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ImageBuilder do
  let(:output) { executor.output.messages }
  let(:executor) { TerminalExecutor.new(OutputBuffer.new, verbose: true, project: project) } # verbose
  let(:project) { projects(:test) }
  let(:build) { project.builds.create!(git_ref: 'v123', git_sha: 'a' * 40, creator: users(:admin)) }
  let(:image_id) { '2d2b0b3204b0166435c3d96d0b27d0ad2083e5e040192632c58eeb9491d6bfaa' }
  let(:digest) { 'sha256:5f1d7c7381b2e45ca73216d7b06004fdb0908ed7bb8786b62f2cdfa5035fde2c' }

  before do
    Build.any_instance.stubs(:validate_git_reference)
  end

  describe ".build_image" do
    let(:docker_image) { Docker::Image.new(Docker.connection, "id" => image_id) }

    def call(options = {})
      defaults = {tag_as_latest: false, dockerfile: 'Dockerfile', tag: 'tag', cache_from: 'cache'}
      ImageBuilder.build_image("foo", build, executor, defaults.merge(options))
    end

    it "builds and pushes" do
      executor.expects(:execute).with do |*commands|
        if commands.to_s.include? "docker pull cache"
          executor.output.write "Successfully built #{image_id}"
        elsif commands.to_s.include? "docker push"
          executor.output.write "Digest: #{digest}"
        else
          raise "UNKNOWN: #{commands}"
        end
        true
      end.times(2).returns(true)

      with_env DOCKER_KEEP_BUILT_IMGS: "1" do
        call.must_equal "docker-registry.example.com/foo@#{digest}"
      end
    end

    it "builds with" do
      executor.expects(:execute).with do |*commands|
        commands.to_s.must_include "cd foo"
        commands.to_s.must_include "docker pull cache" # used cache-from
        commands.to_s.must_include "export DOCKER_CONFIG=" # uses local login credentials
        commands.to_s.must_include "docker build -f Dockerfile -t tag . --cache-from cache"
        true
      end.returns(true)
      refute call
    end

    it "builds without cache" do
      executor.expects(:execute).with do |*commands|
        commands.to_s.wont_include "docker pull cache" # used cache-from
        commands.to_s.wont_include "--cache-from"
        true
      end.returns(true)
      refute call(cache_from: nil)
    end

    it "tells the user that building without at least one docker registry wont work" do
      with_registries [] do
        assert_raises Samson::Hooks::UserError do
          call
        end
      end
    end

    it "can build without tag" do
      executor.expects(:execute).with do |*commands|
        commands.to_s.must_include "docker build -f Dockerfile . --cache-from cache"
      end.returns(true)
      refute call(tag: nil)
    end

    it "fails when build fails" do
      executor.expects(:execute).returns(false)
      refute call
    end

    describe "when building the image worked" do
      def expect_removal
        TerminalExecutor.any_instance.expects(:execute).with("docker rmi -f #{image_id}")
      end

      before { ImageBuilder.expects(:build_image_locally).returns(image_id) }

      it "removes when succeeded" do
        ImageBuilder.expects(:push_image).returns(digest)
        expect_removal
        call.must_equal digest
      end

      it "does not remove image when DOCKER_KEEP_BUILT_IMGS is set" do
        ImageBuilder.expects(:push_image).returns(digest)
        with_env DOCKER_KEEP_BUILT_IMGS: "1" do
          call.must_equal digest
        end
      end

      it "removes build even when pushing failed" do
        ImageBuilder.expects(:push_image).raises
        expect_removal
        assert_raises { call }
      end
    end
  end

  describe ".local_docker_login" do
    run_inside_of_temp_directory

    it "yields and returns" do
      (ImageBuilder.send(:local_docker_login) { 1 }).must_equal 1
    end

    it "reads files for gcr auth with _json_key" do
      path = File.expand_path("some/file")
      with_registries ["https://_json_key:#{CGI.escape(path)}@gcr.io/foo"] do
        Dir.mkdir(File.dirname(path))
        File.write(path, {foo: "bar"}.to_json)
        commands = nil
        (ImageBuilder.send(:local_docker_login) { |c| commands = c })
        commands.join("\n").must_include "docker login --username _json_key --password \\{\\\"foo\\\":\\\"bar\\\"\\}"
      end
    end

    describe "login commands" do
      let(:called) do
        all = []
        ImageBuilder.send(:local_docker_login) { |commands| all = commands }
        all
      end

      before do
        DockerRegistry.expects(:all).returns([DockerRegistry.new("http://fo+o:ba+r@ba+z.com")])
        ImageBuilder.class_variable_set(:@@docker_major_version, nil)
      end

      it "uses email flag when docker is old" do
        ImageBuilder.expects(:read_docker_version).returns("1.12.0")
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r --email no@example.com ba\\+z.com"
      end

      it "uses email flag when docker check fails" do
        ImageBuilder.expects(:read_docker_version).raises(Timeout::Error)
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r --email no@example.com ba\\+z.com"
      end

      it "does not use email flag on newer docker versions" do
        ImageBuilder.expects(:read_docker_version).returns("17.0.0")
        called[1].must_equal "docker login --username fo\\+o --password ba\\+r ba\\+z.com"
      end

      it "can do a real docker check" do
        called # checking that it does not blow up ... result varies depending on if docker is installed
      end
    end

    it "copies previous config files from ENV location" do
      File.write("config.json", "hello")
      with_env DOCKER_CONFIG: '.' do
        ImageBuilder.send(:local_docker_login) do |commands|
          dir = commands.first[/DOCKER_CONFIG=(.*)/, 1]
          File.read("#{dir}/config.json").must_equal "hello"
        end
      end
    end

    it "does not copy when config file does not exist" do
      with_env DOCKER_CONFIG: '.' do
        ImageBuilder.send(:local_docker_login) do |commands|
          dir = commands.first[/DOCKER_CONFIG=(.*)/, 1]
          refute File.exist?("#{dir}/config.json")
        end
      end
    end

    it "copies previous config files from HOME location" do
      Dir.mkdir(".docker")
      File.write(".docker/config.json", "hello")
      with_env HOME: Dir.pwd do
        ImageBuilder.send(:local_docker_login) do |commands|
          dir = commands.first[/DOCKER_CONFIG=(.*)/, 1]
          File.read("#{dir}/config.json").must_equal "hello"
        end
      end
    end
  end

  describe ".push_image" do
    def stub_push(repo, tag, result)
      executor.expects(:execute).with do |*commands|
        executor.output.puts push_output.join("\n")
        commands.to_s.include?("export DOCKER_CONFIG") &&
          commands.to_s.include?("docker tag #{image_id} #{repo}:#{tag}") &&
          commands.to_s.include?("docker push #{repo}:#{tag}")
      end.returns(result)
    end

    def call(**args)
      args = {tag_as_latest: false}.merge(args)
      ImageBuilder.send(:push_image, image_id, build, executor, **args)
    end

    let(:push_output) do
      [
        "pushing image to repo...",
        "Ignore this Digest: #{digest.tr("5", "F")}",
        "completed push.",
        "Frobinating...",
        +"Digest: #{digest}"
      ]
    end
    let(:tag) { 'my-test' }
    let(:primary_repo) { project.docker_repo(DockerRegistry.first, 'Dockerfile') }

    before { build.docker_tag = tag }

    it 'stores generated repo digest' do
      stub_push primary_repo, tag, true
      call.must_equal "#{primary_repo}@#{digest}", output
    end

    it 'uses a different repo for a uncommon dockerfile' do
      build.update_column(:dockerfile, "Dockerfile.secondary")
      stub_push "#{primary_repo}-secondary", tag, true

      call.must_equal "#{primary_repo}-secondary@#{digest}", output
    end

    it 'saves docker output to the buffer' do
      stub_push primary_repo, tag, true
      assert call
      output.must_include 'Frobinating...'
    end

    it 'fails when digest cannot be found' do
      assert push_output.reject! { |e| e =~ /Digest/ }
      stub_push primary_repo, tag, true

      refute call, output
      output.must_include "Docker push failed: Unable to get repo digest"
    end

    describe "with secondary registry" do
      let(:secondary_repo) { project.docker_repo(DockerRegistry.all.to_a[1], 'Dockerfile') }

      with_registries ["docker-registry.example.com", 'extra.registry']

      it "pushes to primary and secondary registry" do
        build.docker_tag.must_equal tag
        stub_push secondary_repo, tag, true
        stub_push primary_repo, tag, true
        assert call, output
      end

      it "stops and fails when pushing to primary registry fails" do
        stub_push primary_repo, tag, false
        refute call, output
      end

      it "fails when pushing to secondary registry fails" do
        stub_push primary_repo, tag, true
        stub_push secondary_repo, tag, false
        refute call, output
      end
    end

    describe 'pushing latest' do
      it 'adds the latest tag on top of the one specified' do
        stub_push(primary_repo, tag, true)
        stub_push(primary_repo, 'latest', true)

        assert call(tag_as_latest: true), output
      end

      it 'does not add the latest tag on top of the one specified when that tag is latest' do
        build.docker_tag = 'latest'
        stub_push(primary_repo, 'latest', true)

        assert call(tag_as_latest: true), output
      end
    end
  end
end
