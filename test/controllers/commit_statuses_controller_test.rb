# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CommitStatusesController do
  as_a :viewer do
    unauthorized :get, :show, stage_id: 'staging', project_id: 'foo', id: 'test/test'
  end

  as_a :project_deployer do
    describe '#show' do
      def call
        CommitStatus.stubs(new: stub(commit_status_data))
        get :show, params: valid_params
      end

      let(:stage) { stages(:test_staging) }
      let(:project) { projects(:test) }
      let(:valid_params) { {project_id: project.to_param, stage_id: stage.to_param, id: 'test/test', ref: 'bar'} }
      let(:commit_status_data) do
        {
          state: 'pending',
          statuses: [{status: 'pending', description: 'the Travis build is still running'}]
        }
      end

      it 'responds with the status' do
        call
        response.body.must_equal(JSON.dump(commit_status_data))
      end

      it "escapes html so we can display in js" do
        status = commit_status_data[:statuses][0]
        status[:context] = status[:description] = "<a>hi</a><script>no</script>"
        call
        response.body.must_equal(JSON.dump(commit_status_data))
      end

      it "fails with unknown project" do
        valid_params[:project_id] = 'baz'
        assert_raises(ActiveRecord::RecordNotFound) { call }
      end

      it "fails with unknown stage" do
        stage.update_column(:project_id, 3)
        assert_raises(ActiveRecord::RecordNotFound) { call }
      end

      it "fails without ref" do
        valid_params.delete :ref
        assert_raises(ActionController::ParameterMissing) { call }
      end
    end
  end
end
