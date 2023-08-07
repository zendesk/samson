# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered! uncovered: 3

describe Kubernetes::Util do
  describe '.parse_file' do
    let(:input_hash) do
      {
        'foo' => 'bar',
        'number' => 123,
        'bool' => true
      }
    end

    it 'handles a JSON file' do
      output = Kubernetes::Util.parse_file(input_hash.to_json, 'file.json')
      output.must_equal input_hash
    end

    it 'handles a YAML file' do
      output = Kubernetes::Util.parse_file(input_hash.to_yaml, 'file.yaml')
      # YAML files always get returned as an array of entries
      output.must_equal [input_hash]
    end

    it 'handles a YAML file with multiple entries' do
      yaml_input = <<~YAML
        ---
        name: foo
        value: 999
        ---
        name: other_key
        value: 1000
        password: 12345
      YAML

      output = Kubernetes::Util.parse_file(yaml_input, 'file.yaml')
      output.must_be_kind_of Array
      output.count.must_equal 2
      output[0].must_equal('name' => 'foo', 'value' => 999)
      output[1].must_equal('name' => 'other_key', 'value' => 1000, 'password' => 12345)
    end

    it 'only loads allowed classes' do
      yaml_input = <<~YAML
        ---
          - !ruby/object:Gem::Installer
              i: x
      YAML
      assert_raises(Psych::DisallowedClass) { Kubernetes::Util.parse_file(yaml_input, 'file.yaml') }
    end
  end
end
