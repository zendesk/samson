# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ImageBuilder do
  let(:executor) { TerminalExecutor.new(OutputBuffer.new, verbose: true) }

  describe ".build_image" do
    it "builds" do
      executor.expects(:execute).with do |*commands|
        commands.to_s.must_include "cd foo"
        commands.to_s.must_include "docker pull cache" # used cache-from
        commands.to_s.must_include "export DOCKER_CONFIG=" # uses local login credentials
        commands.to_s.must_include "docker build -f Dockerfile -t tag . --cache-from cache"
        true
      end.returns(true)
      ImageBuilder.build_image("foo", executor, dockerfile: 'Dockerfile', tag: 'tag', cache_from: 'cache')
    end

    it "builds without cache" do
      executor.expects(:execute).with do |*commands|
        commands.to_s.wont_include "docker pull cache" # used cache-from
        commands.to_s.wont_include "--cache-from"
        true
      end.returns(true)
      ImageBuilder.build_image("foo", executor, dockerfile: 'Dockerfile', tag: 'tag')
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
end
