require_relative '../test_helper'

SingleCov.covered!

describe EnvironmentSerializer do
  let(:environment) { environments(:production) }
  let(:parsed) { JSON.parse(EnvironmentSerializer.new(environment).to_json).with_indifferent_access }

  it 'serializes the basic information' do
    parsed[:environment][:id].must_equal environment.id
    parsed[:environment][:name].must_equal environment.name
    parsed[:environment][:permalink].must_equal environment.permalink
    parsed[:environment][:production].must_equal environment.production
    parsed[:environment][:created_at].must_equal environment.created_at
    parsed[:environment][:updated_at].must_equal environment.updated_at
    parsed[:environment][:deleted_at].must_equal environment.deleted_at
  end

  it 'serializes the deploy groups' do
    parsed[:environment][:deploy_groups].wont_be_nil
    parsed[:environment][:deploy_groups].count.must_equal environment.deploy_groups.count
    parsed[:environment][:deploy_groups].each do |dg|
      dg[:id].to_s.wont_be_empty
      dg[:name].wont_be_empty
    end
  end
end
