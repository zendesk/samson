require_relative '../test_helper'

describe Version do

  describe "#initialize" do

    let(:versioning_schema) { "v{major}.{minor}.{patch}" }
    let(:version_str) { "v1.86.2" }

    describe "when given a versioning schema and version_str" do
      let(:version) { Version.new(versioning_schema, version_str) }

      it "parses the version_str values" do
        assert_send([version, :parse_version_data, version_str])
        assert_equal version.to_s, "v1.86.2"
      end
    end

    describe "when given only a versioning schema " do
      let(:version) { Version.new(versioning_schema) }

      it "builds the initial version" do
        assert_send([version, :build_initial_version])
        assert_equal version.to_s, "v0.0.1"
      end
    end

  end

  describe "instance methods" do

    let(:versioning_schema) { "v{major}.{minor}.{patch}" }
    let(:version_str) { "v1.86.2" }
    let(:version) { Version.new(versioning_schema, version_str) }

    describe "#component_keys" do
      it "returns an array of version components parsed from the versioning schema" do
        assert_equal version.component_keys, ['major', 'minor', 'patch']
      end
    end

    describe "#parse_version_data" do
      it "returns a hash with component_keys and their values" do
        assert_equal version.data['major'], 1
        assert_equal version.data['minor'], 86
        assert_equal version.data['patch'], 2
      end
    end

    describe "#bump" do
      describe "when given no arguments" do
        it "bumps the version's last component by 1" do
          assert_equal version.bump.to_s, "v1.86.3"
        end
      end

      describe "when given a bump_type" do
        it "bumps the specified component" do
          assert_equal version.bump('major'), "v2.86.2"
          assert_equal version.bump('minor'), "v2.87.2"
          assert_equal version.bump('patch'), "v2.87.3"
        end
      end
    end
  end

end
