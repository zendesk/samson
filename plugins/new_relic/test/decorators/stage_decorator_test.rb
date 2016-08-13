# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  describe "new_relic_applications" do
    it "accepts nested attributes" do
      stage = Stage.new(new_relic_applications_attributes: [{name: 'Foo'}])
      stage.new_relic_applications.first.name.must_equal "Foo"
    end

    it "does not accept attributes from a form that was left blank" do
      stage = Stage.new(new_relic_applications_attributes: [{}])
      stage.new_relic_applications.size.must_equal 0
    end
  end
end
