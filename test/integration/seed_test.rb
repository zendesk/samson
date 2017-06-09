# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

describe "seeds" do
  it "can load seeds" do
    User.delete_all
    DeployGroup.delete_all
    Environment.delete_all
    Project.delete_all
    Stage.delete_all
    Release.delete_all
    Project.any_instance.expects(:clone_repository)
    assert_difference 'Project.count', +1 do
      require "#{Rails.root}/db/seeds"
    end
  end
end
