# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Lockable do
  describe 'associations' do
    class MockModelOne < User; end

    it 'adds lock association' do
      instance = MockModelOne.new

      assert_raises NoMethodError do
        instance.lock
      end

      MockModelOne.class_eval { include Lockable } # use existing model for table access

      instance.lock.must_equal nil
    end
  end

  describe "#locked_by?" do
    class MockModelTwo < User
      include Lockable
    end

    def stub_lock(resource, global = true, resource_equal = true)
      lock_instance_mock = mock
      lock_instance_mock.expects(:global?).returns(global)
      lock_instance_mock.expects(:resource_equal?).with(resource).returns(resource_equal) unless global
      lock_instance_mock
    end

    let(:resource) { MockModelTwo.new }

    it 'returns true if global' do
      lock = stub_lock(resource)
      resource.locked_by?(lock).must_equal true
    end

    it "returns true if not global but is resource's lock" do
      lock = stub_lock(resource, false)
      resource.locked_by?(lock).must_equal true
    end

    it "returns false if not global or resource's key" do
      lock = stub_lock(resource, false, false)
      resource.locked_by?(lock).must_equal false
    end
  end
end
