# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Syslog::Formatters do
  describe '.json' do
    it 'returns a json formatted log' do
      output = StringIO.new
      logger = Logger.new(output)
      logger.formatter = Syslog::Formatters::Json.new
      logger.info('test')
      output.string.must_equal "{:severity=>\"INFO\", :time=>#{Time.now}, :message=>\"test\"}"
    end
  end
end
