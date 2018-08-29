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

  describe '#webhook_help_text' do
    it 'renders help text for ci_pipeline source' do
      webhook_help_text('ci_pipeline').must_include('Generic endpoint to start deploys')
    end

    it 'renders nothing if no source matches' do
      webhook_help_text('badabingbadaboom').must_equal ''
    end
  end
end
