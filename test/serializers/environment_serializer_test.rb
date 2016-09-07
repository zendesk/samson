# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe EnvironmentSerializer do
  let(:environment) { environments(:production) }
  let(:parsed) { JSON.parse(EnvironmentSerializer.new(environment).to_json).with_indifferent_access }

  before do
    environment.created_at = environment.updated_at = environment.deleted_at = Time.at(123456)
  end

  it 'serializes the basic information' do
    parsed[:id].must_equal environment.id
    parsed[:name].must_equal environment.name
    parsed[:permalink].must_equal environment.permalink
    parsed[:production].must_equal environment.production
    parsed[:created_at].must_equal "1970-01-02T10:17:36.000Z"
    parsed[:updated_at].must_equal "1970-01-02T10:17:36.000Z"
    parsed[:deleted_at].must_equal "1970-01-02T10:17:36.000Z"
  end

  it 'serializes the deploy groups' do
    parsed[:deploy_groups].wont_be_nil
    parsed[:deploy_groups].count.must_equal environment.deploy_groups.count
    parsed[:deploy_groups].each do |dg|
      dg[:id].to_s.wont_be_empty
      dg[:name].wont_be_empty
    end
  end
end
