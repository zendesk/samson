# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonAwsEcr::Engine do
  def clear_client
    if SamsonAwsEcr::Engine.instance_variable_defined?(:@ecr_client)
      SamsonAwsEcr::Engine.remove_instance_variable(:@ecr_client)
    end
  end

  def self.restore_ecr_state
    around do |test|
      begin
        old = Rails.application.config.samson.docker.registry
        clear_client
        test.call
      ensure
        clear_client
        Rails.application.config.samson.docker.registry = old
      end
    end
  end

  let(:stage) { stages(:test_staging) }
  let(:ecr_client) { Aws::ECR::Client.new(stub_responses: true, region: 'us-west-2') }
  let(:username) { "AWS" }
  let(:password) { "Some password" }
  let(:base64_authorization_token)     { Base64.encode64(username + ":" + password) }
  let(:old_base64_authorization_token) { Base64.encode64("old #{username}:old #{password}") }
  let(:fresh_response) do
    {authorization_data: [{authorization_token: base64_authorization_token, expires_at: 2.hour.from_now}]}
  end
  let(:expired_response) do
    {authorization_data: [{authorization_token: old_base64_authorization_token, expires_at: 2.hour.ago}]}
  end
  let(:matching_ecr_registry) { '12322323232323.dkr.ecr.us-west-1.amazonaws.com' }

  describe :before_docker_build do
    def fire
      Samson::Hooks.fire(:before_docker_build, 'foobar', builds(:docker_build), StringIO.new)
    end

    run_inside_of_temp_directory

    around do |t|
      begin
        old_time = SamsonAwsEcr::Engine.send(:credentials_expire_at)
        SamsonAwsEcr::Engine.send(:credentials_expire_at=, nil)
        t.call
      ensure
        SamsonAwsEcr::Engine.send(:credentials_expire_at=, old_time)
      end
    end

    before { SamsonAwsEcr::Engine.stubs(:ecr_client).returns(ecr_client) }

    describe '.refresh_credentials' do
      it "changes the DOCKER_REGISTRY_USER and DOCKER_REGISTRY_PASS" do
        ecr_client.stub_responses(:get_authorization_token, fresh_response)

        fire

        ENV['DOCKER_REGISTRY_USER'].must_equal username
        ENV['DOCKER_REGISTRY_PASS'].must_equal password
      end

      it "does not request new credentials if they are not expired" do
        ecr_client.stub_responses(:get_authorization_token, fresh_response)

        fire
        fire

        ENV['DOCKER_REGISTRY_USER'].must_equal username
        ENV['DOCKER_REGISTRY_PASS'].must_equal password
      end

      it "requests new credentials if they have expired" do
        ecr_client.stub_responses(:get_authorization_token, expired_response, fresh_response)

        fire
        fire

        ENV['DOCKER_REGISTRY_USER'].must_equal username
        ENV['DOCKER_REGISTRY_PASS'].must_equal password
      end

      it "tells the user what the problem is when unable to authenticate to AWS" do
        assert_raises Samson::Hooks::UserError do
          ecr_client.
            expects(:get_authorization_token).
            raises(Aws::ECR::Errors::InvalidSignatureException.new("XXX", {}))
          fire
        end
      end

      it "returns user/pass so kubenretes plugin can use it" do
        ecr_client.stub_responses(:get_authorization_token, fresh_response)
        fire.must_include([username, password])
      end
    end

    describe '.ensure_repository' do
      before do
        ENV.stubs(fetch: 'x')
        SamsonAwsEcr::Engine.send(:credentials_expire_at=, 2.hour.from_now)
      end

      it 'creates missing repository' do
        ecr_client.
          expects(:describe_repositories).
          with(repository_names: ['foo']).
          raises(Aws::ECR::Errors::RepositoryNotFoundException.new('x', {}))
        ecr_client.
          expects(:create_repository).
          with(repository_name: 'foo')
        fire
      end

      it 'does nothing when repository already exists' do
        ecr_client.
          expects(:describe_repositories).
          with(repository_names: ['foo'])
        ecr_client.expects(:create_repository).never
        fire
      end

      it 'does nothing when client is not allowed to describe the repository (build UI shows repo missing error)' do
        ecr_client.
          expects(:describe_repositories).
          raises(Aws::ECR::Errors::AccessDenied.new("XXX", {}))
        fire
      end

      it 'does nothing when client is not allowed to create the repository (build UI shows repo missing error)' do
        ecr_client.
          expects(:describe_repositories).
          raises(Aws::ECR::Errors::RepositoryNotFoundException.new('x', {}))
        ecr_client.
          expects(:create_repository).
          raises(Aws::ECR::Errors::AccessDenied.new("XXX", {}))
        fire
      end
    end
  end

  describe '.ecr_client' do
    restore_ecr_state

    it 'is cached when matching' do
      stub_request(:get, %r{/latest/meta-data/iam/security-credentials/})
      Rails.application.config.samson.docker.registry = matching_ecr_registry
      SamsonAwsEcr::Engine.send(:ecr_client).object_id.must_equal SamsonAwsEcr::Engine.send(:ecr_client).object_id
    end

    it 'is cached when not matching' do
      refute SamsonAwsEcr::Engine.send(:ecr_client)
      Rails.application.config.samson.docker.registry = matching_ecr_registry
      refute SamsonAwsEcr::Engine.send(:ecr_client)
    end
  end

  describe '.active?' do
    restore_ecr_state

    it "is inactive when not on ecr" do
      refute SamsonAwsEcr::Engine.active?
    end

    it "is active when on ecr" do
      Rails.application.config.samson.docker.registry = matching_ecr_registry
      stub_request(:get, "http://169.254.169.254/latest/meta-data/iam/security-credentials/")
      assert SamsonAwsEcr::Engine.active?
    end
  end
end
