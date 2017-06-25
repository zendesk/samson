# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AuditsHelper do
  describe "#readable_ruby_value" do
    it "keeps regular things" do
      readable_ruby_value("Foo").to_s.must_equal '"Foo"'
    end

    it "makes BigDecimal look nice" do
      readable_ruby_value(BigDecimal.new(1.2, 2)).to_s.must_equal '1.2'
    end
  end

  describe "#text_diff" do
    it "produces a safe diff" do
      diff = text_diff("a", "<script>alert(1)</script>")
      diff.must_include "<del>a</del>"
      diff.must_include "<ins><strong>&lt;script&gt;</strong>a<strong>lert(1)&lt;/script&gt;</strong></ins>"
      assert diff.html_safe?
    end
  end
end
