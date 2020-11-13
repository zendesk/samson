# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Samson::SyslogFormatter do
  before { freeze_time }

  describe "#call" do
    let(:output) { StringIO.new }
    let(:logger) do
      l = Logger.new(output)
      l.formatter = Samson::SyslogFormatter.new
      l
    end
    let(:log_template) do
      {level: "INFO", "@timestamp": Time.now.as_json, application: "samson", host: "www.test-url.com", tags: []}
    end

    def clean_log
      output.string.gsub("}{", "}\n{").split("\n").map do |line|
        line = JSON.parse(line, symbolize_names: true)
        line.delete_if { |k, v| log_template[k] == v }
        line
      end
    end

    it 'returns a json formatted log' do
      logger.info('test')
      clean_log.must_equal [{message: 'test'}]
    end

    it 'merges Hash into log' do
      message = {content: "xyz", data: "123"}
      logger.info(message)
      clean_log.must_equal [message]
    end

    it 'returns original message with invalid json' do
      message = "{\"content\",\"xyz\",\"data\",\"123\"}"
      logger.info(message)
      clean_log.must_equal [{message: message}]
    end

    it 'merges json messages into log' do
      message = {content: "xyz"}
      logger.info(message.to_json)
      clean_log.must_equal [message]
    end

    it 'skips parser when message isn`t hash' do
      message = "[1,2]"
      logger.info(message)
      clean_log.must_equal [{message: message}]
    end

    it "can add/remove tags" do
      logger.info("1")
      logger.formatter.tagged(["foo"]) do
        logger.info("2")
        logger.formatter.tagged(["bar", "baz"]) do
          logger.info("3")
        end
        logger.info("4")
      end
      logger.info("5")
      clean_log.must_equal [
        {message: "1"},
        {tags: ["foo"], message: "2"},
        {tags: ["foo", "bar", "baz"], message: "3"},
        {tags: ["foo"], message: "4"},
        {message: "5"}
      ]
    end

    it "can clear tags" do
      logger.info("1")
      logger.formatter.tagged(["foo", "bar"]) do
        logger.formatter.clear_tags!
        logger.info("2")
      end
      logger.info("3")
      clean_log.must_equal [
        {message: "1"},
        {message: "2"},
        {message: "3"}
      ]
    end
  end
end

describe Syslog::Logger do
  describe "#silence" do
    it "does nothing" do
      Syslog::Logger.new.silence { 1 }.must_equal 1
    end
  end
end
