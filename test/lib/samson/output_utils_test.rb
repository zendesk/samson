# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::OutputUtils do
  describe '.timestamp' do
    it 'returns a formatted timestamp' do
      freeze_time
      Samson::OutputUtils.timestamp.must_equal '[04:05:06]'
    end
  end
end
