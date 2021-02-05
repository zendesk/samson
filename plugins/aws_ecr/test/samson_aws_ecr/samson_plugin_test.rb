# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

describe SamsonAwsEcr::SamsonPlugin do
  def clear_client
    SamsonAwsEcr::SamsonPlugin.instance_variable_set(:@ecr_clients, nil)
  end

  let(:stage) { stages(:test_staging) }
  let(:ecr_client) { Aws::ECR::Client.new(stub_responses: true, region: 'us-west-2') }
  let(:username) { "AWS" }
  let(:password) { "Some password" }
  let(:base64_authorization_token)     { Base64.encode64("#{username}:#{password}") }
  let(:old_base64_authorization_token) { Base64.encode64("old #{username}:old #{password}") }
  let(:fresh_response) do
    {authorization_data: [{authorization_token: base64_authorization_token, expires_at: 2.hours.from_now}]}
  end
  let(:expired_response) do
    {authorization_data: [{authorization_token: old_base64_authorization_token, expires_at: 2.hours.ago}]}
  end

  with_registries ['12322323232323.dkr.ecr.us-west-1.amazonaws.com']

  # reset ECR state
  around do |test|
    begin
      clear_client
      test.call
    ensure
      clear_client
    end
  end

  before { stub_request(:put, "http://169.254.169.254/latest/api/token").to_return(status: 404) }

  describe :before_docker_repository_usage do
    let(:build) { builds(:docker_build) }

    def fire
      Samson::Hooks.fire(:before_docker_repository_usage, build)
    end

    run_inside_of_temp_directory

    before { SamsonAwsEcr::SamsonPlugin.stubs(:ecr_client).returns(ecr_client) }

    describe '.refresh_credentials' do
      it "changes the username and password" do
        ecr_client.stub_responses(:get_authorization_token, fresh_response)

        fire

        DockerRegistry.first.username.must_equal username
        DockerRegistry.first.password.must_equal password
      end

      it "does not request new credentials if they are not expired" do
        ecr_client.stub_responses(:get_authorization_token, fresh_response)

        fire
        fire

        DockerRegistry.first.username.must_equal username
        DockerRegistry.first.password.must_equal password
      end

      it "requests new credentials if they have expired" do
        ecr_client.stub_responses(:get_authorization_token, expired_response, fresh_response)

        fire
        fire

        DockerRegistry.first.username.must_equal username
        DockerRegistry.first.password.must_equal password
      end

      it "tells the user what the problem is when unable to authenticate to AWS" do
        assert_raises Samson::Hooks::UserError do
          ecr_client.
            expects(:get_authorization_token).
            raises(Aws::ECR::Errors::InvalidSignatureException.new("XXX", {}))
          fire
        end
      end
    end

    describe '.ensure_repositories' do
      before do
        ENV.stubs(fetch: 'x')
        DockerRegistry.first.credentials_expire_at = 2.hours.from_now
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

      it 'derives repository from dockerfile' do
        build.update_column :dockerfile, 'Dockerfile.foobar'
        ecr_client.expects(:describe_repositories).with(repository_names: ['foo-foobar'])
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

  describe '.ecr_clients' do
    it 'is caches' do
      assert_request(:get, %r{/latest/meta-data/iam/security-credentials/}, times: 3) do
        Array.new(2).map do
          SamsonAwsEcr::SamsonPlugin.send(:ecr_client, DockerRegistry.first).object_id
        end.uniq.size.must_equal 1
      end
    end
  end

  describe '.active?' do
    it "is inactive when not on ecr" do
      DockerRegistry.first.instance_variable_get(:@uri).host = 'xyz.com'
      refute SamsonAwsEcr::SamsonPlugin.active?
    end

    it "is active when on ecr" do
      assert_request(:get, "http://169.254.169.254/latest/meta-data/iam/security-credentials/", times: 3) do
        assert SamsonAwsEcr::SamsonPlugin.active?
      end
    end
  end
end
