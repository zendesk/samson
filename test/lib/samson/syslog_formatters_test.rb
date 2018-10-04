# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::SyslogFormatter do
  describe '.json' do
    before do
      @output = StringIO.new
      @logger = Logger.new(@output)
      @logger.formatter = Samson::SyslogFormatter.new
      @log_template = {level: "INFO", "@timestamp": Time.now, application: "samson", host: "www.test-url.com"}
    end

    it 'returns a json formatted log' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = 'test'
        @log_template[:"@timestamp"] = Time.now
        @logger.info(message)
        expected = @log_template.merge(message: message)
        @output.string.must_equal(expected.to_json)
      end
    end

    it 'parse and format json messages' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = {content: "xyz", data: "123"}
        @log_template[:"@timestamp"] = Time.now
        @logger.info(message)
        expected = @log_template.merge(message)
        @output.string.must_equal(expected.to_json)
      end
    end

    it 'skips parser when message isn`t hash' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = "[1,2]"
        @log_template[:"@timestamp"] = Time.now
        @logger.info(message)
        expected = @log_template.merge(message: message)
        @output.string.must_equal(expected.to_json)
      end
    end
  end
end
