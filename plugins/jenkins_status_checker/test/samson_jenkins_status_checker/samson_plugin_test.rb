# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe JenkinsStatusChecker do
  describe :project_permitted_params do
    it "adds jenkins_status_checker" do
      params = Samson::Hooks.fire(:project_permitted_params).flatten
      params.must_include :jenkins_status_checker
    end
  end
end
