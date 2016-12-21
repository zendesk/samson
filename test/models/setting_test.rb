# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Setting do
  after { (Setting.instance_variable_get(:@cache) || {}).clear }

  describe "validations" do
    let(:setting) { Setting.new(name: 'FOO_BAZ123', value: 'BAR') }

    it "is valid" do
      assert_valid setting
    end

    it "is invalid without name" do
      setting.name = ''
      refute_valid setting
    end

    it "is invalid with non ENV like name" do
      setting.name = 'sdsdf'
      refute_valid setting
    end
  end

  describe "[]" do
    it "falls back to ENV" do
      Setting['DATADOG_API_KEY'].must_equal 'dapikey'
    end

    it "checks setting first" do
      Setting['DATADOG_API_KEY'] = 'FOO'
      Setting['DATADOG_API_KEY'].must_equal 'FOO'
      ENV['DATADOG_API_KEY'].must_equal 'dapikey'
    end

    it "can fail" do
      Setting['FOO'].must_equal nil
    end
  end

  describe "#update_cache" do
    it "adds to cache" do
      Setting.create!(name: 'FOO', value: 'BAR')
      Setting['FOO'].must_equal 'BAR'
    end

    it "updates to cache" do
      setting = Setting.create!(name: 'FOO', value: 'BAR')
      setting.update_attributes!(value: 'BAZ')
      Setting['FOO'].must_equal 'BAZ'
    end
  end

  describe "#remove_from_cache" do
    it "removes from cache" do
      setting = Setting.create!(name: 'FOO', value: 'BAR')
      setting.destroy!
      Setting['FOO'].must_equal nil
    end
  end
end
