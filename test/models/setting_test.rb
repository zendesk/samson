# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Setting do
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
end
