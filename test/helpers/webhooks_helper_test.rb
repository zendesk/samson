# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe WebhooksHelper do
  describe '#webhook_sources_for_select' do
    it "renders" do
      webhook_sources_for_select(["foo"]).must_equal [
        ["Any", "any"],
        ["Any CI", "any_ci"],
        ["Any code push", "any_code"],
        ["Any Pull Request", "any_pull_request"],
        ["Foo", "foo"]
      ]
    end

    it "renders with none action" do
      webhook_sources_for_select(["foo"], none: true).must_equal [
        ["Any", "any"],
        ["Any CI", "any_ci"],
        ["Any code push", "any_code"],
        ["Any Pull Request", "any_pull_request"],
        ["None", 'none'],
        ["Foo", "foo"]
      ]
    end
  end
end
