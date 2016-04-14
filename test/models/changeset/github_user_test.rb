require_relative '../../test_helper'

SingleCov.covered! uncovered: 8

describe Changeset::GithubUser do
  describe "#avatar_url" do
    it "returns the URL for the user's avatar" do
      data = stub("data", avatar_url: "https://avatars.githubusercontent.com/u/1337?v=2")

      user = Changeset::GithubUser.new(data)
      user.avatar_url.must_equal "https://avatars.githubusercontent.com/u/1337?v=2&s=20"
    end
  end
end
