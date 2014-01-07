require_relative '../../test_helper'
require 'execution/base'

describe Execution::Base do
  subject { Execution::Base.new }

  it 'sets the callbacks up' do
    subject.callbacks[:stdout].must_equal([])
    subject.callbacks[:stderr].must_equal([])
  end

  describe "#output" do
    before do
      subject.output { puts 'hi' }
    end

    it 'keeps the callback' do
      subject.callbacks[:stdout].size.must_equal(1)
    end
  end

  describe "#error_output" do
    before do
      subject.error_output { puts 'hi' }
    end

    it 'keeps the callback' do
      subject.callbacks[:stderr].size.must_equal(1)
    end
  end

  describe "execute!" do
    it 'raises an exception' do
      lambda { subject.execute! }.must_raise(ArgumentError)
    end
  end
end
