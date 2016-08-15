# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::DeploysController do
  oauth_setup!
  describe '#active_count' do
    before do
      Deploy.stubs(:active).returns(['a'])
      get :active_count
    end

    it 'responds successfully' do
      assert_response :success
    end

    it 'responds as json' do
      response.content_type.must_equal 'application/json'
    end

    it 'returns as expected' do
      response.body.must_equal "1"
    end
  end

  describe 'get #index' do
    let(:project) { job.project }
    let(:stage) { stages(:test_staging) }
    let(:admin) { users(:admin) }
    let(:command) { job.command }
    let(:job) { jobs(:succeeded_test) }
    let(:deploy) { deploys(:succeeded_test) }
    let(:deploy_service) { stub(deploy!: nil, stop!: nil) }
    let(:deploy_called) { [] }
    let(:changeset) { stub_everything(commits: [], files: [], pull_requests: [], jira_issues: []) }

    before do
      get :index, project_id: project.to_param
    end

    subject { JSON.parse(response.body) }

    describe 'when the current project has a deploy' do
      it 'succeeds' do
        assert_response :success
        response.content_type.must_equal 'application/json'
      end

      it 'renders 1 deploy' do
        subject.size.must_equal 1
      end
    end

    describe 'when an id is passed in' do
      before do
        deploy2 = deploys(:succeeded_production_test)
        get :index, project_id: project.to_param, ids: [deploy.id, deploy2.id]
      end

      it 'succeeds' do
        assert_response :success
        response.content_type.must_equal 'application/json'
      end

      it 'renders the deploy' do
        subject['deploys'].size.must_equal 2
      end

      it 'consists of an array of objects' do
        subject.keys.must_equal ['deploys']
        subject['deploys'].first.keys.sort.must_equal ["id", "production", "project", "status", \
                                                       "summary", "updated_at", "url", "user"]
      end
    end
  end

  describe 'Doorkeeper Auth Status' do
    subject { @controller }
    it 'is allowed' do
      subject.class.api_accessible.must_equal true
    end
  end
end
