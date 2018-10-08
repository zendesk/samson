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

    def output_matcher(message, output)
      @log_template[:"@timestamp"] = Time.now
      @logger.info(message)
      expected = @log_template.merge(output)
      @output.string.must_equal(expected.to_json)
    end

    it 'returns a json formatted log' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = 'test'
        output_matcher(message, message: message)
      end
    end

    it 'allows Hash and appends to log' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = {content: "xyz", data: "123"}
        output_matcher(message, message)
      end
    end

    it 'returns original message with invalid json' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = "{\"content\",\"xyz\",\"data\",\"123\"}"
        output_matcher(message, message: message)
      end
    end

    it 'parse and format json messages' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = {content: "xyz"}
        output_matcher(message.to_json, message)
      end
    end

    it 'skips parser when message isn`t hash' do
      travel_to Time.parse("2017-05-01 01:00 +0000").utc do
        message = "[1,2]"
        output_matcher(message, message: message)
      end
    end
  end
end
