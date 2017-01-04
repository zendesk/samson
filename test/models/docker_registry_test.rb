# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DockerRegistry do
  describe ".check_config!" do
    before { DockerRegistry.expects(:abort).never }

    it "passes with only DOCKER_REGISTRIES" do
      DockerRegistry.check_config!
    end

    it "passes with only DOCKER_REGISTRY" do
      with_env DOCKER_REGISTRIES: nil, DOCKER_REGISTRY: 'ssdsdfd' do
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

      it "warns when using single deprecated registry var" do
        DockerRegistry.expects(:warn)
        with_env DOCKER_REGISTRY: 'xxx' do
          registry = DockerRegistry.all.first
          registry.base.must_equal 'xxx'
          registry.username.must_equal nil
          registry.password.must_equal nil
        end
      end

      it "warns when using multiple deprecated registry vars" do
        DockerRegistry.expects(:warn)
        with_env(
          DOCKER_REGISTRY: 'xxx',
          DOCKER_REGISTRY_USER: 'usr',
          DOCKER_REGISTRY_PASS: 'pas',
          DOCKER_REPO_NAMESPACE: 'name'
        ) do
          registry = DockerRegistry.all.first
          registry.base.must_equal 'xxx/name'
          registry.username.must_equal 'usr'
          registry.password.must_equal 'pas'
        end
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
  end

  describe "#base" do
    it "returns host and namespace" do
      DockerRegistry.new('foo.bar/baz').base.must_equal 'foo.bar/baz'
    end

    it "returns host when no namespace was used" do
      DockerRegistry.new('foo.bar').base.must_equal 'foo.bar'
    end
  end
end
