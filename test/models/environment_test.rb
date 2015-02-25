require_relative '../test_helper'

describe Environment do
  it 'should be saved with valid name' do
    env = Environment.new(name: 'test deploy name', is_production: true)
    env.valid?.must_equal true
    env.save.must_equal true
    env.reload.name.must_equal 'test deploy name'
    env.is_production.must_equal true
  end

  it 'should require a name' do
    env = Environment.new(name: nil)
    env.valid?.must_equal false
  end

  it 'should default false for is_production' do
    env = Environment.new(name: 'foo')
    env.save.must_equal true
    env.reload.name.must_equal 'foo'
    env.is_production.must_equal false
  end

  it 'should require a unique name' do
    deploy_group = Environment.new(name: 'Production')
    deploy_group.valid?.must_equal false
  end
end
