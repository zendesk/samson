# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CommitStatusesController do
  as_a :viewer do
    unauthorized :get, :show, stage_id: 'staging', project_id: 'foo', id: 'test/test'
  end

  as_a :project_deployer do
    describe '#show' do
      let(:project) { projects(:test) }
      let(:valid_params) { {project_id: project.to_param, id: 'test/test', ref: 'bar'} }
      let(:commit_status_data) do
        {
          state: 'pending',
          statuses: [{status: 'pending', description: 'the Travis build is still running'}]
        }
      end

      context 'without stage' do
        before do
          CommitStatus.stubs(new: stub(commit_status_data))
          get :show, params: valid_params
        end

        it 'responds ok' do
          response.status.must_equal(200)
        end

        it 'responds with the status' do
          response.body.must_equal(JSON.dump(commit_status_data))
        end
      end

      context 'with stage' do
        let(:stage) { stages(:test_staging) }
        let(:params) { valid_params.merge(stage_id: stage.to_param) }

        context 'valid' do
          before do
            CommitStatus.expects(new: stub(commit_status_data)).with(project, 'bar', stage: stage)
            get :show, params: params
          end

          it 'responds ok' do
            response.status.must_equal(200)
          end

          it 'responds with the status' do
            response.body.must_equal(JSON.dump(commit_status_data))
          end
        end

        it "fails with unknown stage" do
          stage.update_column(:project_id, 3)
          assert_raises(ActiveRecord::RecordNotFound) { get :show, params: params }
        end
      end

      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: valid_params.merge(project_id: 'baz')
        end
      end

      it "fails without ref" do
        assert_raises ActionController::ParameterMissing do
          get :show, params: valid_params.merge(ref: nil)
        end
      end
    end
  end
end
