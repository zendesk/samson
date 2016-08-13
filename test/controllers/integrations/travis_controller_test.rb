# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Integrations::TravisController do
  extend IntegrationsControllerTestHelper

  let(:sha) { "123abc" }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  before do
    Deploy.delete_all
    @orig_token = ENV["TRAVIS_TOKEN"]
    ENV["TRAVIS_TOKEN"] = "TOKEN"
    project.webhooks.create!(stage: stages(:test_staging), branch: "master", source: 'travis')
  end

  after do
    ENV["TRAVIS_TOKEN"] = @orig_token
  end

  describe "#create" do
    def create(options = {})
      post :create, {token: project.token, payload: JSON.dump(payload)}.merge(options)
    end

    let(:authorization) { Digest::SHA2.hexdigest("bar/foo#{ENV["TRAVIS_TOKEN"]}") }
    let(:user) { users(:deployer) }
    let(:status_message) { 'Passed' }
    let(:commit_message) { 'A change' }
    let(:payload) do
      {
        status_message: status_message,
        branch: 'master',
        message: commit_message,
        committer_email: user.email,
        commit: sha,
        type: 'push'
      }
    end

    before do
      @request.headers["Authorization"] = authorization if authorization
    end

    it "fails with unknown project" do
      assert_raises ActiveRecord::RecordNotFound do
        create token: 'sdasda'
      end
    end

    describe "with no authorization" do
      let(:authorization) { nil }

      it "renders ok" do
        create
        response.status.must_equal(200)
      end
    end

    describe "with invalid authorization" do
      let(:authorization) { "BLAHBLAH" }

      it "renders ok" do
        create
        response.status.must_equal(200)
      end
    end

    describe "failure" do
      let(:payload) do
        {
          status_message: 'Failure',
          branch: 'sdavidovitz/blah',
          message: 'A change'
        }
      end

      it "renders ok" do
        create
        response.status.must_equal(200)
      end
    end

    describe "with status_message 'Passed'" do
      it "creates a deploy" do
        create
        deploy = project.deploys.first
        deploy.try(:commit).must_equal(sha)
      end
    end

    describe "with status_message 'Fixed'" do
      let(:status_message) { 'Fixed' }

      it "creates a deploy" do
        create
        deploy = project.deploys.first
        deploy.try(:commit).must_equal(sha)
      end
    end

    describe 'skipping' do
      def payload
        {payload: JSON.dump(super)}
      end

      it_ignores_skipped_commits
    end
  end
end
