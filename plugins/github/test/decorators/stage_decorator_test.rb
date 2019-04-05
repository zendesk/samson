# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage) { Stage.new }

  it('allows supported keys') do
    stage.github_pull_request_comment = 'This %{stage_name} has this ref: %{reference}'

    stage.save

    stage.errors.messages[:github_pull_request_comment].must_be_empty
  end

  it('throws validation error if unsupported keys are used') do
    stage.github_pull_request_comment = 'This is %{unsupported}'

    stage.save

    stage.errors.messages[:github_pull_request_comment].must_equal ['key{unsupported} not found']
  end

  it('handles no github_pull_request_comment') do
    stage.github_pull_request_comment = nil

    stage.save

    stage.errors.messages[:github_pull_request_comment].must_be_empty
  end
end
