# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe BuildSerializer do
  let(:build) { builds(:staging) }
  let(:parsed) { JSON.parse(BuildSerializer.new(build).to_json) }

  it 'serializes create at to milliseconds' do
    parsed['created_at'].must_equal build.created_at.to_i * 1000
  end
end
