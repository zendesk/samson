# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProjectSerializer do
  let(:project) { projects(:test) }
  let(:serializer) { ProjectSerializer.new(project) }
  let(:parsed) { JSON.parse(serializer.to_json) }

  it 'serializes url' do
    parsed['url'].must_equal "http://www.test-url.com/projects/foo"
  end

  describe '.csv_header' do
    it 'returns an array of strings' do
      header = ProjectSerializer.csv_header
      header.must_be_kind_of Array
      header.first.must_equal 'Id'
    end
  end

  describe '#csv_line' do
    it 'returns a CSV line' do
      line = serializer.csv_line
      line.must_be_kind_of Array
      line.first.must_equal project.id
    end
  end
end
