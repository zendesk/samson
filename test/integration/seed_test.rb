# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.not_covered!

describe "seeds" do
  it "can load seeds" do
    DeployGroup.delete_all
    Environment.delete_all
    Project.delete_all
    Stage.delete_all
    assert_difference 'Project.count', +1 do
      require "#{Rails.root}/db/seeds"
    end
  end
end
