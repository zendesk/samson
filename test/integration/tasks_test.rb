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
    File.read("db/schema.rb").wont_include "4294967295", "replace 4294967295 with 1073741823"
    tasks["db:schema:dump"].execute

    if ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      # normalize ... travis is set up with weird charsets
      # TODO: make it not produce a diff without these hacks
      actual = File.read("db/schema.rb")
      actual.gsub!(", options: \"ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC\", force: :cascade", "") || raise
      actual.gsub!('"resource_template", limit: 4294967295', '"resource_template", limit: 1073741823') || raise
      actual.gsub!('"object", limit: 4294967295', '"object", limit: 1073741823') || raise
      actual.gsub!('"output", limit: 4294967295', '"output", limit: 268435455') || raise
      actual.gsub!('"audited_changes", limit: 4294967295', '"audited_changes", limit: 1073741823') || raise
      File.write("db/schema.rb", actual)

      diff = `git diff -- db/schema.rb`
      assert diff.empty?, diff
    end
  end
end
