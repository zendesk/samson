# frozen_string_literal: true
# rubocop:disable Layout/LineLength
require_relative '../../test/test_helper'

SingleCov.covered!

describe JenkinsStatusChecker do
  with_env(JENKINS_STATUS_CHECKER: '/StagingStatus')
  describe ".instance" do
    it "has an available singleton instance" do
      assert_instance_of JenkinsStatusChecker, JenkinsStatusChecker.instance
    end
  end

  describe "#checklist" do
    before do
      stub_request(:get, "http://www.test-url.com/StagingStatus/api/json").
        to_return(body: json_response)
    end

    describe "when not all the environment variables are set" do
      let(:json_response) { "" }
      [{JENKINS_STATUS_CHECKER: nil}, {JENKINS_URL: nil}].each do |env_var|
        with_env(env_var)

        it "returns a missing key error" do
          message = /Error: key not found/
          assert_match(message, JenkinsStatusChecker.instance.checklist[0])
        end
      end
    end

    describe "when there are errors connecting" do
      let(:json_response) { "" }

      it "reports timeout errors" do
        JenkinsApi::Client.any_instance.stubs(:api_get_request).raises(Timeout::Error)
        message = ["Error: Timeout::Error"]
        assert_equal(message, JenkinsStatusChecker.instance.checklist)
      end

      it "reports api errors" do
        # needs a logger to instantiate
        JenkinsApi::Client.any_instance.stubs(:api_get_request).raises(JenkinsApi::Exceptions::ApiException.new(Rails.logger), "Error message")
        message = ["Error: Error message"]
        assert_equal(message, JenkinsStatusChecker.instance.checklist)
      end
    end

    describe "when all jobs are green" do
      let(:json_response) { '{"_class":"hudson.model.ListView","description":null,"jobs":[{"_class":"hudson.model.FreeStyleProject","name":"account_service_staging_pod998","url":"https://jenkins.test.com/job/account_service_staging_pod998/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"account_service_staging_pod999","url":"https://jenkins.test.com/job/account_service_staging_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"answer_bot_pod998_staging_status","url":"https://jenkins.test.com/job/answer_bot_pod998_staging_status/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"AppDeveloper_Staging_998_Status","url":"https://jenkins.test.com/job/AppDeveloper_Staging_998_Status/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"Voice_Staging_999_Status","url":"https://jenkins.test.com/job/Voice_Staging_999_Status/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"widget_staging_status_pod998","url":"https://jenkins.test.com/job/widget_staging_status_pod998/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"widget_staging_status_pod999","url":"https://jenkins.test.com/job/widget_staging_status_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"WIP_answer_bots_on_pod999","url":"https://jenkins.test.com/job/WIP_answer_bots_on_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"WIP_csat_predictions_pod999","url":"https://jenkins.test.com/job/WIP_csat_predictions_pod999/","color":"blue"}],"name":"StagingStatus","property":[],"url":"https://jenkins.test.com/view/StagingStatus/"}' }

      it "returns a go ahead message" do
        message = ['All projects stable!']
        assert_equal(message, JenkinsStatusChecker.instance.checklist)
      end
    end

    describe "when there are failing jobs" do
      let(:json_response) { '{"_class":"hudson.model.ListView","description":null,"jobs":[{"_class":"hudson.model.FreeStyleProject","name":"account_service_staging_pod998","url":"https://jenkins.test.com/job/account_service_staging_pod998/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"account_service_staging_pod999","url":"https://jenkins.test.com/job/account_service_staging_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"answer_bot_pod998_staging_status","url":"https://jenkins.test.com/job/answer_bot_pod998_staging_status/","color":"red"},{"_class":"hudson.model.FreeStyleProject","name":"AppDeveloper_Staging_998_Status","url":"https://jenkins.test.com/job/AppDeveloper_Staging_998_Status/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"Voice_Staging_999_Status","url":"https://jenkins.test.com/job/Voice_Staging_999_Status/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"widget_staging_status_pod998","url":"https://jenkins.test.com/job/widget_staging_status_pod998/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"widget_staging_status_pod999","url":"https://jenkins.test.com/job/widget_staging_status_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"WIP_answer_bots_on_pod999","url":"https://jenkins.test.com/job/WIP_answer_bots_on_pod999/","color":"blue"},{"_class":"hudson.model.FreeStyleProject","name":"WIP_csat_predictions_pod999","url":"https://jenkins.test.com/job/WIP_csat_predictions_pod999/","color":"red"}],"name":"StagingStatus","property":[],"url":"https://jenkins.test.com/view/StagingStatus/"}' }
      it "returns a list of failing jobs" do
        message = ["answer_bot_pod998_staging_status is red", "WIP_csat_predictions_pod999 is red"]
        assert_equal(message, JenkinsStatusChecker.instance.checklist)
      end
    end
  end
end
# rubocop:enable Layout/LineLength
