# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

describe "db" do
  let(:maxitest_timeout) { 10 }

  let_all(:tasks) do
    Rails.application.load_tasks # cannot be in before since it would load multiple times
    Rake::Task
  end

  it "can load seeds" do
    User.delete_all
    DeployGroup.delete_all
    Environment.delete_all
    Project.delete_all
    Stage.delete_all
    Release.delete_all
    Project.any_instance.expects(:clone_repository)
    assert_difference 'Project.count', +2 do
      tasks["db:seed"].execute
    end
  end

  it "can dump the schema without diff" do
    tasks["db:schema:dump"]
    if ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      File.read("db/schema.rb").wont_include "4294967295", "replace 4294967295 with 1073741823"
      `git diff -- db/schema.rb`.must_equal ""
    end
  end
end
