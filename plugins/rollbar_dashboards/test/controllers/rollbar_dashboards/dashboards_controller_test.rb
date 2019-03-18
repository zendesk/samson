# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::DashboardsController do
  let(:setting) do
    RollbarDashboards::Setting.create!(
      project: projects(:test),
      base_url: 'https://bingbong.gov/api/1',
      read_token: '12345'
    )
  end
  let(:deploy) { deploys(:succeeded_test) }

  describe "#project_dashboard" do
    def get_dashboard(project)
      get :project_dashboard, params: {project_id: project}
    end

    let(:project) { projects(:test) }
    let(:endpoint) do
      "#{setting.base_url}/reports/top_active_items?access_token=12345&hours=24&environments=production"
    end
    let(:item) { {title: 'Crazy Error', environment: 'production', occurrences: 9000} }

    as_a :viewer do
      it 'renders project dashboard' do
        assert_request(:get, endpoint, to_return: {body: {result: [item: item]}.to_json}) do
          get_dashboard(project)
          assert_select '.panel-heading', 'Top 4 Items in the Last 24 Hours (https://bingbong.gov/api/1)'
          assert_select '.badge', '9000'
          assert_select 'td', 'Crazy Error'
          assert_select 'td', 'production'
        end
      end

      it 'renders empty dashboard if items are nil' do
        assert_request(:get, endpoint, to_return: {status: 400}) do
          get_dashboard(project)
          assert_select 'p', text: 'There are no items to display at this time...'
        end
      end

      it 'renders empty dashboard if there are no items' do
        assert_request(:get, endpoint, to_return: {body: {result: []}.to_json}) do
          get_dashboard(project)
          assert_select 'p', text: 'There are no items to display at this time...'
        end
      end

      it 'caches the project items' do
        assert_request(:get, endpoint, to_return: {body: {result: [item: item]}.to_json}) do
          get_dashboard(project)
          assert_select '.badge', '9000'
          assert_select 'td', 'Crazy Error'
          assert_select 'td', 'production'
        end

        get_dashboard(project) # Request result was cached

        assert_select '.badge', '9000'
        assert_select 'td', 'Crazy Error'
        assert_select 'td', 'production'
      end
    end
  end

  describe "#deploy_dashboard" do
    def get_dashboard(deploy)
      get :deploy_dashboard, params: {deploy_id: deploy}
    end

    def stub_deploy_rql_query(return_value)
      @controller.expects(:deploy_rql_query).returns(return_value)
    end

    def assert_create_rql_job(params: {}, return_value: {body: {result: {id: 1}}.to_json}, &block)
      params = {body: {access_token: '12345', query_string: query, force_refresh: '1'}.merge(params)}

      assert_request :post, rql_create_endpoint, with: params, to_return: return_value, &block
    end

    def assert_rql_job_result(return_value, &block)
      assert_request :get, rql_result_endpoint, to_return: return_value, &block
    end

    let(:query) { 'select * from all_the_things' }
    let(:rql_create_endpoint) { "#{setting.base_url}/rql/jobs" }
    let(:rql_result_endpoint) { "#{setting.base_url}/rql/job/1/result?access_token=12345" }
    let(:items) do
      {
        body: {
          result: {
            result: {
              rows: [[123, 'A most terrible error', 'production']],
              columns: ['occurrences', 'title', 'environment']
            }
          }
        }.to_json
      }
    end

    as_a :viewer do
      it 'renders deploy dashboard' do
        stub_deploy_rql_query(query)

        assert_create_rql_job do
          assert_rql_job_result(items) do
            get_dashboard(deploy)
            assert_select '.badge', '123'
            assert_select 'td', 'A most terrible error'
            assert_select 'td', 'production'
          end
        end
      end

      it 'caches items' do
        stub_deploy_rql_query(query)

        assert_create_rql_job do
          assert_rql_job_result(items) do
            get_dashboard(deploy)
            assert_select '.badge', '123'
            assert_select 'td', 'A most terrible error'
            assert_select 'td', 'production'
          end
        end

        get_dashboard(deploy) # items are cached
        assert_select '.badge', '123'
        assert_select 'td', 'A most terrible error'
        assert_select 'td', 'production'
      end

      it 'renders no items when job id is nil' do
        stub_deploy_rql_query(query)

        assert_create_rql_job(return_value: {status: 400}) do
          get_dashboard(deploy)
          assert_select 'p', text: 'There are no items to display at this time...'
        end
      end

      it 'renders no items when items are nil' do
        ErrorNotifier.expects(:notify)
        stub_deploy_rql_query(query)

        assert_create_rql_job do
          assert_rql_job_result(body: 'invalidstuffs') do
            get_dashboard(deploy)
            assert_select 'p', text: 'There are no items to display at this time...'
          end
        end
      end
    end
  end

  describe "#deploy_rql_query" do
    it 'returns correct query' do
      expected = <<~RQL.squish
        SELECT timestamp DIV 86400 as t,
               item.counter as counter,
               item.title as title,
               Count(*) as occurrences,
               item.environment as environment
        FROM   item_occurrence
        WHERE  environment = "staging"
               AND timestamp >= 1388605800
        GROUP  BY 1,
                  item.counter
        ORDER  BY 4 DESC
        LIMIT  4
      RQL

      @controller.send(:deploy_rql_query, deploy).must_equal expected
    end

    it 'returns query with range timestamp if there is a next succeeded deploy' do
      Deploy.create!(
        release: true,
        project: deploy.project,
        stage: deploy.stage,
        job: deploy.job,
        reference: 'v1.0',
        created_at: '2014-01-02 19:50:00'
      )

      expected = <<~RQL.squish
        SELECT timestamp DIV 86400 as t,
               item.counter as counter,
               item.title as title,
               Count(*) as occurrences,
               item.environment as environment
        FROM   item_occurrence
        WHERE  environment = "staging"
               AND timestamp BETWEEN 1388605800 and 1388692200
        GROUP  BY 1,
                  item.counter
        ORDER  BY 4 DESC
        LIMIT  4
      RQL

      @controller.send(:deploy_rql_query, deploy).must_equal expected
    end
  end
end
