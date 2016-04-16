require_relative '../test_helper'

SingleCov.covered!

describe WebhooksHelper do
  describe '#webhook_sources' do
    it "renders" do
      webhook_sources(["foo"]).must_equal [
        ["Any CI", "any_ci"],
        ["Any code push", "any_code"],
        ["Any Pull Request", "any_pull_request"],
        ["Any", "any"],
        ["Foo", "foo"]
      ]
    end
  end
end
