# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { stages(:test_staging) }

  describe "#validate_github_pull_request_comment_variables" do
    it "allows empty comment" do
      assert_valid stage
    end

    it "allows supported keys" do
      stage.github_pull_request_comment = "This %{stage_name} has this ref: %{reference}"
      assert_valid stage
    end

    it "does not allow unsupported keys" do
      stage.github_pull_request_comment = "This is %{unsupported}"
      refute_valid stage
      stage.errors.full_messages.must_equal ["Github pull request comment key{unsupported} not found"]
    end

    it "does not allow invalid format" do
      stage.github_pull_request_comment = "This is %{"
      refute_valid stage
      stage.errors.full_messages.must_equal ["Github pull request comment malformed name - unmatched parenthesis"]
    end
  end
end
