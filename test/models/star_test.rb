# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Star do
  describe "#expire_user_cache" do
    let(:user) { users(:viewer) }
    let(:project) { projects(:test) }
    let(:key) { [:starred_projects_ids, user.id] }

    it "expires on create" do
      Rails.cache.write(key, 1)
      Star.create!(project: project, user: user)
      Rails.cache.read(key).must_be_nil
    end

    it "expires on destroy" do
      star = Star.create!(project: project, user: user)
      Rails.cache.write(key, 1)
      star.destroy
      Rails.cache.read(key).must_be_nil
    end
  end
end
