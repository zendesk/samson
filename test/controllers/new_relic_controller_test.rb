require_relative '../test_helper'

SingleCov.covered!

describe NewRelicController do
  before do
    NewRelicApi.api_key = 'hello'
  end

  as_a_viewer do
    unauthorized :get, :show, project_id: :foo, id: 1
  end

  as_a_project_deployer do
    describe "#show" do
      it "requires a project" do
        assert_raises(ActiveRecord::RecordNotFound) do
          get :show, project_id: 123123, id: 123123
        end
      end

      it "requires a stage" do
        assert_raises(ActiveRecord::RecordNotFound) do
          get :show, project_id: projects(:test), id: 123123
        end
      end

      it "requires a NewReclic api key" do
        begin
          old, NewRelicApi.api_key = NewRelicApi.api_key, ""
          get :show, project_id: projects(:test), id: 123123
        ensure
          NewRelicApi.api_key = old
        end
        assert_response :precondition_failed
      end

      describe "success" do
        before do
          NewRelic.expects(:metrics).
            with([new_relic_applications(:production).name], initial).
            returns('test_project' => true)

          get :show, project_id: projects(:test),
            id: stages(:test_staging).id,
            initial: initial ? 'true' : nil
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
