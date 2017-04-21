# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe Environment do
  describe '.new' do
    it 'saves' do
      env = Environment.new(name: 'test deploy name', production: true)
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'test deploy name'
      env.production.must_equal true
    end

    it 'default false for production' do
      env = Environment.new(name: 'foo')
      assert_valid(env)
      env.save.must_equal true
      env.reload.name.must_equal 'foo'
      env.production.must_equal false
    end
  end

  describe ".env_deploygroup_array" do
    it "includes All" do
      all = Environment.env_deploygroup_array
      all.map! { |name, value| [name, value&.sub(/-\d+/, '-X')] }
      all.must_equal(
        [
          ["All", nil],
          ["Production", "Environment-X"],
          ["Staging", "Environment-X"],
          ["----", nil],
          ["Pod1", "DeployGroup-X"],
          ["Pod2", "DeployGroup-X"],
          ["Pod 100", "DeployGroup-X"]
        ]
      )
    end

    it "does not includes All when requested" do
      Environment.env_deploygroup_array(include_all: false).wont_include ["All", nil]
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

  describe '#template_stages' do
    let(:env) { environments(:staging) }

    it 'finds the template stages' do
      refute env.template_stages.empty?
    end
  end
end
