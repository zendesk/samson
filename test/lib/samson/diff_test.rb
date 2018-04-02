# frozen_string_literal: true
#
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Diff do
  describe "#text_diff" do
    it "produces a safe diff" do
      diff = Samson::Diff.text_diff("a", "<script>alert(1)</script>")
      diff.must_include "<del>a</del>"
      diff.must_include "<ins><strong>&lt;script&gt;</strong>a<strong>lert(1)&lt;/script&gt;</strong></ins>"
      assert diff.html_safe?
    end
  end

  describe "#style_tag" do
    it 'renders style' do
      Samson::Diff.style_tag.must_include '<style>'
    end
  end
end
