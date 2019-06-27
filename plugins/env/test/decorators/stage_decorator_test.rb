# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  it "accepts environment_variables" do
    stage = Stage.new(environment_variables_attributes: {0 => {name: "Foo", value: "bar"}})
    stage.environment_variables.map(&:name).must_equal ["Foo"]
  end
end
