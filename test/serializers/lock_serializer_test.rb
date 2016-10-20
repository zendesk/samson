# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe LockSerializer do
  let(:lock) { Lock.create!(user: users(:admin)) }
  let(:parsed) { JSON.parse(LockSerializer.new(lock).to_json).deep_symbolize_keys }

  before do
    lock.created_at = lock.updated_at = lock.deleted_at = Time.at(123456)
  end

  it 'serializes the basic information' do
    parsed.must_equal(
      id: lock.id,
      resource_id: nil,
      resource_type: nil,
      user_id: lock.user_id,
      warning: false,
      created_at: "1970-01-02T10:17:36.000Z"
    )
  end
end
