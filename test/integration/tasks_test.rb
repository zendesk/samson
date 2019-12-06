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

  it "produces the current schema from checked in migrations" do
    tasks["db:schema:dump"].execute

    if ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      # additional expected diff can be mitigated in lib/tasks/dump.rake where we hook into db:schema:dump
      content = File.read("db/schema.rb")
      refute content.include?("4294967295"), "replace 4294967295 with 1073741823 in db/schema.rb\n#{content}"

      diff = `git diff -- db/schema.rb`
      assert diff.empty?, diff
    end
  end
end
