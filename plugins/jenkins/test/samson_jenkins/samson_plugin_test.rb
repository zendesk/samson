# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe SamsonJenkins do
  it "calls deployed! on deploy" do
    Samson::Jenkins.expects(:deployed!)
    Samson::Hooks.fire :after_deploy, deploys(:succeeded_test), stub(output: nil)
  end

  describe :stage_permitted_params do
    it "adds parameters" do
      Samson::Hooks.fire(:stage_permitted_params).flatten.must_include :jenkins_job_names
    end
  end
end
