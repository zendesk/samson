# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe ScopesEnvironmentVariables do
  it "adds scoped_environment_variables" do
    Environment.new.scoped_environment_variables.must_equal []
  end

  it "deletes environment variables on destruction" do
    environment = Environment.create!(name: 'foo')
    variable = EnvironmentVariable.create!(scope: environment, parent: projects(:test), name: 'bar', value: 'baz')
    environment.scoped_environment_variables.must_equal [variable]

    assert_difference("EnvironmentVariable.count", -1) { environment.destroy! }
  end
end
