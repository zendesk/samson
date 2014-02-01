require_relative '../test_helper'

describe NewRelicController do
  as_a_deployer do
    describe 'without a project' do
      setup do
        get :show, project_id: 123123, id: 123123
      end

      it 'renders 404' do
        response.status.must_equal(404)
      end
    end

    describe 'with a project' do
      describe 'without a stage' do
        setup do
          get :show, project_id: projects(:test), id: 123123
        end

        it 'renders 404' do
          response.status.must_equal(404)
        end
      end

      describe 'with a stage' do
        setup do
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
        end
      end
    end

    describe 'without a new_relic_api key' do
      setup do
        @original_api_key, NewRelicApi.api_key = NewRelicApi.api_key, nil
        get :show, project_id: projects(:test), id: 123123
      end

      teardown do
        NewRelicApi.api_key = @original_api_key
      end

      it 'renders 404' do
        response.status.must_equal(404)
      end
    end
  end
end
