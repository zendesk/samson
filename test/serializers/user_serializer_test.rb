# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserSerializer do
  let(:user) { users(:admin) }
  let(:parsed) { JSON.parse(UserSerializer.new(user).to_json) }

  it 'serializes' do
    parsed['gravatar_url'].must_equal "https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61"
  end
end
