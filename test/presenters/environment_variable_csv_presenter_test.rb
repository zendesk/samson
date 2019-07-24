# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe EnvironmentVariableCsvPresenter do
  describe ".to_csv" do
    before do
      EnvironmentVariableGroup.create!(
        environment_variables_attributes: {
          0 => {name: "X", value: "Y"},
          1 => {name: "A", value: "B"}
        },
        name: "G1"
      )
      EnvironmentVariable.create!(parent: projects(:test), name: 'foo', value: 'bar')
    end

    it "generates csv with correct number of rows" do
      EnvironmentVariableCsvPresenter.to_csv.split("\n").size.must_equal 4
    end
  end

  describe ".csv_header" do
    it "returns the list of column headers" do
      EnvironmentVariableCsvPresenter.send(:csv_header).must_equal(
        [
          "name",
          "value",
          "parent"
        ]
      )
    end
  end
end
