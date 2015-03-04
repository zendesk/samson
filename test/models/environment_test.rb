require_relative '../test_helper'

describe Environment do
  describe '.new' do
    it 'saves' do
      env = Environment.new(name: 'test deploy name', is_production: true)
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'test deploy name'
      env.is_production.must_equal true
    end

    it 'default false for is_production' do
      env = Environment.new(name: 'foo')
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'foo'
      env.is_production.must_equal false
    end
  end

  describe 'validations' do
    it 'fail with no name' do
      env = Environment.new(name: nil)
      refute_valid(env)
    end

    it 'fail with non-unique name' do
      env = Environment.new(name: 'Production')
      refute_valid(env)
    end
  end
end
