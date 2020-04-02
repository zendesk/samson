# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe ExternalEnvironmentVariableGroup do
  def fake_response(response)
    stub(body: stub(read: response))
  end

  with_env EXTERNAL_ENV_GROUP_S3_REGION: "us-east-1", EXTERNAL_ENV_GROUP_S3_BUCKET: "a-bucket"

  let(:s3) { stub("S3") }
  let(:env_group_attributes) do
    {
      name: "A",
      description: "B",
      url: "https://a-bucket.s3.amazonaws.com/key?versionId=version_id",
      project: project
    }
  end
  let(:project) { projects(:test) }

  describe "auditing" do
    let(:group) { ExternalEnvironmentVariableGroup.create!(env_group_attributes) }

    it "record an audit when created" do
      ExternalEnvironmentVariableGroup.any_instance.expects(:read).returns(true)
      group.audits.map(&:audited_changes).must_equal [
        env_group_attributes.except(:project).merge(project_id: project.id).stringify_keys
      ]
    end

    it "record an audit updated" do
      ExternalEnvironmentVariableGroup.any_instance.expects(:read).times(2).returns({})
      group.update!(name: "B")
      group.audits.map(&:audited_changes).must_equal(
        [
          env_group_attributes.except(:project).merge(project_id: project.id).stringify_keys,
          {"name" => ["A", "B"]}
        ]
      )
    end
  end

  describe "validations" do
    let(:group) { ExternalEnvironmentVariableGroup.new(env_group_attributes) }

    before do
      ExternalEnvironmentVariableGroup.any_instance.stubs(:read).returns(true)
    end

    it "is valid" do
      assert_valid group
    end

    describe "validate url" do
      it "is invalid with s3://" do
        group.url = "s3://samson/key"
        refute_valid group
      end

      it "is invalid when it fails to parse s3 key" do
        group.url = "https://a-bucket.s3.amazonaws.com"
        refute_valid group, :url
        group.errors[:url].must_equal(
          ["Invalid format, valid url format is https://.s3.amazonaws.com/[key]?versionId=[version_id]"]
        )
      end

      it "is invalid with wrong bucket" do
        group.url = "https://a-bucket.s3.amazonaws.com"
        refute_valid group, :url
        group.errors[:url].must_equal(
          ["Invalid format, valid url format is https://.s3.amazonaws.com/[key]?versionId=[version_id]"]
        )
      end

      it "fails on invalid bucket" do
        group.url = "https://test.s3.amazonaws.com/key?versionId=version_id"
        refute_valid group, :url
        group.errors.full_messages.must_equal ["Url Invalid: bucket must be a-bucket"]
      end

      it "fails on invalid key" do
        group.expects(:resolve_s3_url).returns(nil)
        refute_valid group, :url
        group.errors.full_messages.must_equal ["Url Invalid: unable to get s3 key or bucket"]
      end
    end

    it "requires a name" do
      group = ExternalEnvironmentVariableGroup.new(env_group_attributes.merge(name: nil))
      refute group.valid?
    end

    it "fails when read fails" do
      ExternalEnvironmentVariableGroup.any_instance.unstub(:read)
      ExternalEnvironmentVariableGroup.any_instance.stubs(:read).raises("foo")
      group.url = "https://test.s3.amazonaws.com/key?versionId=version_id"
      refute_valid group, :url
      group.errors.full_messages.must_equal ["Url Invalid: bucket must be a-bucket"]
    end
  end

  describe "#resolve_s3_url" do
    it "parse url and gets s3 details" do
      group = ExternalEnvironmentVariableGroup.new(env_group_attributes)
      key, bucket, version_id = group.send(:resolve_s3_url)
      key.must_equal "key"
      bucket.must_equal "a-bucket"
      version_id.must_equal "version_id"
    end
  end

  describe "#configured?" do
    it "returns true with env's" do
      ExternalEnvironmentVariableGroup.configured?.wont_be_nil
    end

    it "returns false without env's" do
      with_env EXTERNAL_ENV_GROUP_S3_REGION: nil,
      EXTERNAL_ENV_GROUP_S3_BUCKET: nil do
        refute ExternalEnvironmentVariableGroup.configured?
      end
    end
  end

  describe "#read" do
    before do
      Aws::S3::Client.stubs(:new).returns(s3)
    end
    let(:group) { ExternalEnvironmentVariableGroup.create!(env_group_attributes.merge(project: project)) }

    it "can read" do
      response = {"FOO" => "one"}.to_yaml
      s3.expects(:get_object).times(2).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(response))
      group.read.must_equal "FOO" => "one"
    end

    it "shows error when s3 file is missing" do
      s3.expects(:get_object).raises(Aws::S3::Errors::NoSuchKey.new({}, "The specified key does not exist."))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal(
        "Validation failed: Url Invalid: key \"key\" does not exist in bucket a-bucket!"
      )
    end

    it "tries reading from a DR bucket if available" do
      with_env EXTERNAL_ENV_GROUP_S3_DR_REGION: "us-east-1",
      EXTERNAL_ENV_GROUP_S3_DR_BUCKET: "dr-bucket" do
        response = {"FOO" => "one"}.to_yaml
        s3.expects(:get_object).times(2).with(
          bucket: 'a-bucket', key: 'key', version_id: 'version_id'
        ).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
        s3.expects(:get_object).times(2).with(
          bucket: 'dr-bucket', key: 'key', version_id: 'version_id'
        ).returns(fake_response(response))
        group.read.must_equal "FOO" => "one"
      end
    end

    it "skips DR bucket if not available" do
      s3.expects(:get_object).times(4).with(
        bucket: 'a-bucket', key: 'key', version_id: 'version_id'
      ).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal "Validation failed: Url Invalid: DOWN"
    end

    it "shows error when api times out after multiple retries" do
      s3.expects(:get_object).times(4).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal "Validation failed: Url Invalid: DOWN"
    end

    it "invalid file format as response" do
      response = 123
      s3.expects(:get_object).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(response))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal "Validation failed: Url Invalid: no implicit conversion of Integer into String"
    end

    it "works with a stub record" do
      s3.expects(:get_object).times(2).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response({"FOO" => "one"}.to_yaml))
      g = ExternalEnvironmentVariableGroup.new(url: group.url)
      g.read.must_equal "FOO" => "one"
    end
  end
end
