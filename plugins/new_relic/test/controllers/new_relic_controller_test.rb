# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe NewRelicController do
  with_new_relic_plugin_enabled

  as_a :viewer do
    unauthorized :get, :show, project_id: :foo, stage_id: 1
  end

  as_a :project_deployer do
    describe "#show" do
      it "requires a project" do
        assert_raises(ActiveRecord::RecordNotFound) do
          get :show, params: {project_id: 123123, stage_id: stages(:test_staging)}
        end
      end

      it "requires a stage" do
        assert_raises(ActiveRecord::RecordNotFound) do
          get :show, params: {project_id: projects(:test), stage_id: 123123}
        end
      end

      it "requires a NewReclic api key" do
        silence_warnings { SamsonNewRelic::API_KEY = nil }
        get :show, params: {project_id: projects(:test), stage_id: stages(:test_staging)}
        assert_response :precondition_failed
      end

      describe "success" do
        before do
          SamsonNewRelic::Api.expects(:metrics).
            with([new_relic_applications(:production).name], initial: initial).
            returns('test_project' => true)

          get :show, params: {
            project_id: projects(:test).to_param,
            stage_id: stages(:test_staging).to_param,
            initial: (initial ? 'true' : nil)
          }
        end

        describe 'initial' do
          let(:initial) { true }

          it 'responds 200' do
            response.status.must_equal(200)
          end

          it 'renders json representation' do
            response.body.must_equal(JSON.dump('test_project' => true))
          end
        end

        describe 'not initial' do
          let(:initial) { false }

          it 'responds 200' do
            response.status.must_equal(200)
          end

          it 'renders json representation' do
            response.body.must_equal(JSON.dump('test_project' => true))
          end
        end
      end
    end
  end
end
