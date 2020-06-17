# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe Datadog::MonitorsController do
  as_a :viewer do
    describe "#index" do
      let(:stage) { stages(:test_staging) }

      before do
        host = "https://api.datadoghq.com"
        url = "#{host}/api/v1/monitor/123?api_key=dapikey&application_key=dappkey&group_states=alert,warn"
        stub_request(:get, url).to_return(body: {overall_state: "OK"}.to_json)
        stage.datadog_monitor_queries.create!(query: 123)
      end

      it "renders without layout" do
        get :index, params: {project_id: stage.project, stage_id: stage}
        assert_response :success
        response.body.must_include "monitors/123"
        response.body.wont_include "<html"
      end

      it "renders for projects" do
        stage.project.datadog_monitor_queries.create!(query: 123)
        get :index, params: {project_id: stage.project}
        assert_response :success
        response.body.must_include "monitors/123"
        response.body.wont_include "<html"
      end
    end
  end
end
