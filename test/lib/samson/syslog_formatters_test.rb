# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::SyslogFormatter do
  describe '.json' do
    it 'returns a json formatted log' do
      output = StringIO.new
      logger = Logger.new(output)
      logger.formatter = Samson::SyslogFormatter.new
      logger.info('test')
      output.string.must_equal({severity: "INFO", time: Time.now, message: "test"}.to_json)
    end
  end
end
