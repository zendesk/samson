# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe VersionsHelper do
  describe "#readable_ruby_value" do
    it "keeps regular things" do
      readable_ruby_value("Foo").to_s.must_equal '"Foo"'
    end

    it "makes BigDecimal look nice" do
      readable_ruby_value(BigDecimal.new(1.2, 2)).to_s.must_equal '1.2'
    end
  end
end
