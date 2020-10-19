# frozen_string_literal: true

require_relative '../../test_helper'

SingleCov.covered!

describe Lockable do
  describe 'associations' do
    mock_model_one = Class.new(User) do
      def self.name
        "MockModelOne"
      end
    end

    it 'adds lock association' do
      instance = mock_model_one.new

      assert_raises NoMethodError do
        instance.lock
      end

      mock_model_one.class_eval { include Lockable } # use existing model for table access

      instance.lock.must_equal nil
    end
  end

  describe "#locked_by?" do
    mock_model_two = Class.new(User) do
      include Lockable
    end

    def stub_lock(resource, global: true, resource_equal: true)
      lock_instance_mock = mock
      lock_instance_mock.expects(:global?).returns(global)
      lock_instance_mock.expects(:resource_equal?).with(resource).returns(resource_equal) unless global
      lock_instance_mock
    end

    let(:resource) { mock_model_two.new }

    it 'returns true if global' do
      lock = stub_lock(resource)
      resource.locked_by?(lock).must_equal true
    end

    it "returns true if not global but is resource's lock" do
      lock = stub_lock(resource, global: false)
      resource.locked_by?(lock).must_equal true
    end

    it "returns false if not global or resource's key" do
      lock = stub_lock(resource, global: false, resource_equal: false)
      resource.locked_by?(lock).must_equal false
    end
  end
end
