# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonJenkins do
  it "calls deployed! on deploy" do
    Samson::Jenkins.expects(:deployed!)
    Samson::Hooks.fire :after_deploy, deploys(:succeeded_test), users(:admin)
  end
end
