# frozen_string_literal: true
require_relative '../../test_helper'
SingleCov.covered!

describe Api::DeploysController do
  oauth_setup!

  describe '#active_count' do
    before do
      Deploy.stubs(:active).returns(['a'])
      get :active_count, format: :json
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

  describe '#index' do
    let!(:job_failure) do
      Job.create! do |job|
        job.command = "cap staging deploy"
        job.user = users(:super_admin)
        job.project = project
        job.status = "failed"
        job.output = "Error"
        job.commit = "staging"
      end
    end
    let(:project) { job_success.project }
    let(:stage) { stages(:test_staging) }
    let(:admin) { users(:admin) }
    let(:command) { job.command }
    let(:job_success) { jobs(:succeeded_test) }
    let(:deploy_success) { deploys(:succeeded_test) }
    let!(:deploy_failure) do
      deploy = deploys(:succeeded_test)
      deploy.job_id = job_failure.id
      deploy.stage_id = stage.id
      deploy.save!
      deploy
    end

    describe '#deploy_scope' do
      let(:job_join) { "INNER JOIN `jobs`" }
      let(:params) { { stage_id: stage.id, filter: "succeeded" } }
      let(:sql) { subject.send(:deploy_scope).to_sql.tr('"', '`') }

      subject do
        @controller.stubs(:params).returns(ActionController::Parameters.new(params))
        @controller
      end

      it 'renders a scope specific to the stage' do
        sql.must_include job_join
        sql.must_include "`deploys`.`stage_id` = #{stage.id}"
      end

      describe 'no filter' do
        let(:params) { { stage_id: stage.id } }

        it 'does not include a filter' do
          sql.wont_include job_join
        end
      end

      describe 'if the route is a project' do
        let(:params) { { project_id: project.id, filter: "succeeded" } }

        it 'gives a scope is project based' do
          sql.must_include job_join
          sql.must_include "`deploys`.`project_id` = #{project.id}"
        end
      end
    end

    describe 'for a project' do
      before do
        get :index, params: {project_id: project.id}, format: :json
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

      describe 'with filter parameter' do
        subject do
          get :index, params: params, format: :json
        end

        let(:deploy_response) { JSON.parse(response.body)['deploys'] }

        describe 'invalid filter' do
          let(:params) { { project_id: project.id, filter: 'foo' } }

          it 'returns an error' do
            subject
            response.body.must_include(Job::VALID_STATUSES.join(', '))
            JSON.parse(response.body).keys.must_equal ['error']
            assert_response :bad_request
          end
        end

        ["failed", "succeeded"].each do |status|
          describe "a valid filter (#{status})" do
            let(:params) { { project_id: project.id, filter: status } }
            let!(:deploy) do
              Deploy.where(job_id: Job.where(status: status).pluck(:id)).first
            end

            it 'does not error' do
              subject
              deploy_response.size.must_be :>=, 1
              deploy_response.map { |r| r['id'] }.must_include deploy.id
              deploy_response.map { |d| d['status'] }.uniq.must_equal [status]
              assert_response :success
            end
          end
        end
      end
    end
  end

  describe '#show' do
    it 'renders' do
      get :show, params: {id: deploys(:succeeded_test).id}, format: :json
      assert_response :success
    end
  end
end
