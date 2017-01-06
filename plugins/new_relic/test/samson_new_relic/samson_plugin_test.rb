# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonNewRelic do
  describe :stage_permitted_params do
    it "lists extra keys" do
      found = Samson::Hooks.fire(:stage_permitted_params).detect do |x|
        x.is_a?(Hash) && x[:new_relic_applications_attributes]
      end
      assert found
    end
  end

  describe :stage_clone do
    let(:stage) { stages(:test_staging) }

    it "copies over the new relic applications" do
      stage.new_relic_applications = [NewRelicApplication.new(name: "test", stage_id: stage.id)]
      clone = Stage.build_clone(stage)
      attributes = [stage, clone].map { |s| s.new_relic_applications.map { |n| n.attributes.except("stage_id", "id") } }
      attributes[0].must_equal attributes[1]
    end
  end

  describe ".enabled?" do
    it "is disabled when KEY was not set" do
      refute SamsonNewRelic.enabled?
    end

    describe "when enabled" do
      with_new_relic_plugin_enabled

      it "is enabled when KEY was set" do
        assert SamsonNewRelic.enabled?
      end
    end
  end
end
