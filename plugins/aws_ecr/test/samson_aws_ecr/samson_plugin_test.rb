require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonAwsEcr do
  let(:stage) { stages(:test_staging) }
  let(:ecr_client) { Aws::ECR::Client.new(stub_responses: true, region: 'us-west-2') }
  let(:username) { "AWS" }
  let(:password) { "Some password" }
  let(:base64_authorization_token)     { Base64.encode64(username + ":" + password) }
  let(:new_base64_authorization_token) { Base64.encode64("new #{username}:new #{password}") }

  describe :before_docker_build do
    def fire
      job = stub(deploy: stub(stage: stage), project: stage.project, git_ref: "ref")
      Samson::Hooks.fire(:before_docker_build, "dir", job, StringIO.new)
    end

    around { |test| Dir.mktmpdir { |dir| Dir.chdir(dir) { test.call } } }

    before do
      SamsonAwsEcr::Engine.ecr_client = ecr_client
      SamsonAwsEcr::Engine.credentials_expire_at = Time.current
      FileUtils.mkdir("dir")
    end

    it "changes the DOCKER_REGISTRY_USER and DOCKER_REGISTRY_PASS" do
      SamsonAwsEcr::Engine.ecr_client.stub_responses(:get_authorization_token, {
        authorization_data: [ authorization_token: base64_authorization_token ]
      })

      fire

      ENV['DOCKER_REGISTRY_USER'].must_equal username
      ENV['DOCKER_REGISTRY_PASS'].must_equal password
    end

    it "doesn't request new credentials if they haven't expired" do
      SamsonAwsEcr::Engine.ecr_client.stub_responses(:get_authorization_token, {
        authorization_data: [
          authorization_token: base64_authorization_token, expires_at: Time.now + 2.hours
        ]
      }, {
        authorization_data: [
          authorization_token: base64_authorization_token
        ]
      })

      fire
      fire

      ENV['DOCKER_REGISTRY_USER'].must_equal username
      ENV['DOCKER_REGISTRY_PASS'].must_equal password
    end

    it "requests new credentials if they have expired" do
      SamsonAwsEcr::Engine.ecr_client.stub_responses(:get_authorization_token, {
        authorization_data: [
          authorization_token: base64_authorization_token, expires_at: Time.now - 2.hours
        ]
      }, {
        authorization_data: [
          authorization_token: new_base64_authorization_token, expires_at: Time.now + 2.hours
        ]
      })

      fire
      fire

      ENV['DOCKER_REGISTRY_USER'].must_equal "new #{username}"
      ENV['DOCKER_REGISTRY_PASS'].must_equal "new #{password}"
    end
  end
end
