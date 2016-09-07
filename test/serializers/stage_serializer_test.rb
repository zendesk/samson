# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StageSerializer do
  let(:stage) { stages(:test_staging) }
  let(:parsed) { JSON.parse(StageSerializer.new(stage).to_json) }

  it 'serializes' do
    parsed['id'].must_equal stage.id
  end
end
