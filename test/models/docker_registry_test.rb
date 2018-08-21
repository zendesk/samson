# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerRegistry do
  describe ".check_config!" do
    before { DockerRegistry.expects(:abort).never }

    it "passes with only DOCKER_REGISTRIES" do
      DockerRegistry.check_config!
    end

    it "fails with only DOCKER_REGISTRY" do
      with_env DOCKER_REGISTRIES: nil, DOCKER_REGISTRY: 'ssdsdfd' do
        DockerRegistry.expects(:abort)
        DockerRegistry.check_config!
      end
    end

    it "fails when neither registry is configured" do
      with_env DOCKER_REGISTRIES: nil do
        DockerRegistry.expects(:abort)
        DockerRegistry.check_config!
      end
    end
  end

  describe ".all" do
    describe "without registries" do
      with_registries []

      it "has none if empty" do
        DockerRegistry.all.must_equal []
      end
    end

    describe "simple" do
      with_registries ['foo.bar']

      it "finds simple" do
        DockerRegistry.all.map(&:host).must_equal ['foo.bar']
      end
    end
  end

  describe ".first" do
    with_registries ['foo.bar']

    it "returns first registry" do
      DockerRegistry.first.host.must_equal 'foo.bar'
    end
  end

  describe "#host" do
    it "finds host without protocol" do
      DockerRegistry.new('foo.bar/baz').host.must_equal 'foo.bar'
    end

    it "finds host with protocol" do
      DockerRegistry.new('https://foo.bar/baz').host.must_equal 'foo.bar'
    end

    it "finds host with a non-standard port" do
      DockerRegistry.new('foo.bar:5000/baz').host.must_equal 'foo.bar:5000'
    end
  end

  describe "#base" do
    it "returns host and namespace" do
      DockerRegistry.new('foo.bar/baz').base.must_equal 'foo.bar/baz'
    end

    it "includes port in base" do
      DockerRegistry.new('foo.bar:5000/baz').base.must_equal 'foo.bar:5000/baz'
    end

    it "returns host when no namespace was used" do
      DockerRegistry.new('foo.bar').base.must_equal 'foo.bar'
    end
  end

  describe "#password" do
    it "reads files for json auth like gcr" do
      DockerRegistry.new("https://_json_key:public%2Frobots.txt@foo.bar").password.
        must_equal File.read("public/robots.txt")
    end
  end
end
