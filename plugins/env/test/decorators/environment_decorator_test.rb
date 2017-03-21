# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Environment do
  it "has scoped_environment_variables" do
    environments(:production).scoped_environment_variables.must_equal []
  end
end
