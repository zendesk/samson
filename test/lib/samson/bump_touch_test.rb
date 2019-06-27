# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::BumpTouch do
  describe "#bump_touch" do
    let(:deploy) { deploys(:succeeded_test) }

    before { freeze_time }

    it "touches when not in conflict" do
      deploy.updated_at = 1.minute.ago
      deploy.bump_touch
      deploy.reload.updated_at.must_equal Time.now
    end

    it "bumps when new time would not be a change and cache would not expire" do
      deploy.updated_at = Time.now
      deploy.bump_touch
      deploy.reload.updated_at.must_equal Time.now + 1
    end
  end
end
