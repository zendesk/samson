# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe ExternalEnvironmentVariableGroup do
  def fake_response(response)
    stub(body: stub(read: response))
  end

  with_env EXTERNAL_ENV_GROUP_S3_REGION: "us-east-1",
    EXTERNAL_ENV_GROUP_S3_BUCKET: "a-bucket"
  let(:s3) { stub("S3") }

  let(:env_group_attributes) do
    {
      name: "A",
      description: "B",
      url: "https://a-bucket.s3.amazonaws.com/key?versionId=version_id"
    }
  end
  let(:project) { projects(:test) }

  describe "auditing" do
    before do
      Aws::S3::Client.stubs(:new).returns(s3)
    end
    let(:group) do
      ExternalEnvironmentVariableGroup.create!(
        env_group_attributes.merge(project: project)
      )
    end

    it "record an audit when created" do
      s3.expects(:get_object).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(""))
      group.audits.map(&:audited_changes).must_equal [
        env_group_attributes.merge(project_id: project.id).stringify_keys
      ]
    end

    it "record an audit updated" do
      s3.expects(:get_object).times(2).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(""))
      group.update!(name: "B")
      group.audits.map(&:audited_changes).must_equal(
        [
          env_group_attributes.merge(project_id: project.id).stringify_keys,
          {"name" => ["A", "B"]}
        ]
      )
    end
  end

  describe "validations" do
    before do
      ExternalEnvironmentVariableGroup.any_instance.expects(:read).returns(true)
    end
    describe "validate url" do
      it "valid URL format" do
        group = ExternalEnvironmentVariableGroup.new(env_group_attributes.merge(project: project))
        assert group.valid?
      end

      it "invalid url format" do
        group = ExternalEnvironmentVariableGroup.new(
            env_group_attributes.merge(url: "s3://samson/key")
          )
        refute group.valid?
      end

      it "unable to parse s3 key or bucket" do
        ExternalEnvironmentVariableGroup.any_instance.unstub(:read)
        ExternalEnvironmentVariableGroup.any_instance.expects(:read).never
        group = ExternalEnvironmentVariableGroup.new(
           env_group_attributes.merge(
               project: project,
               url: "https://a-bucket.s3.amazonaws.com"
             )
         )
        refute group.valid?
        group.errors[:url].must_include 'Invalid URL, unable to get s3 key or bucket'
      end
    end

    it "name is mandatory" do
      group = ExternalEnvironmentVariableGroup.new(env_group_attributes.merge(name: nil))
      refute group.valid?
      group.errors[:name].must_include "can't be blank"
    end
  end

  describe "#resolve_s3_url" do
    it "parse url and gets s3 details" do
      group = ExternalEnvironmentVariableGroup.new(env_group_attributes)
      group.send(:resolve_s3_url)
      group.key.must_equal "key"
      group.bucket.must_equal "a-bucket"
      group.version_id.must_equal "version_id"
    end

    it "skips parser" do
      group = ExternalEnvironmentVariableGroup.new
      group.send(:resolve_s3_url)
      group.key.must_be_nil
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
    let(:group) do
      ExternalEnvironmentVariableGroup.create!(
        env_group_attributes.merge(project: project)
      )
    end

    it "valid response" do
      response = {"FOO" => "one"}.to_yaml
      s3.expects(:get_object).times(2).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(response))
      group.read.must_equal "FOO" => "one"
    end

    it "invalid s3 bucket" do
      s3.expects(:get_object).times(1).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(""))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.update!(url: "https://test.s3.amazonaws.com/key?versionId=version_id")
      end
      e.message.must_equal(
        "Validation failed: Url Invalid URL, Invalid s3 bucket, acceptable buckets are a-bucket"
      )
    end

    it "shows error when s3 file is missing" do
      s3.expects(:get_object).raises(Aws::S3::Errors::NoSuchKey.new({}, "The specified key does not exist."))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal(
        "Validation failed: Url Invalid URL, key \"key\" does not exist in bucket a-bucket!"
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
      e.message.must_equal "Validation failed: Url Invalid URL, DOWN"
    end

    it "shows error when api times out after multiple retries" do
      s3.expects(:get_object).times(4).raises(Aws::S3::Errors::ServiceError.new({}, "DOWN"))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal "Validation failed: Url Invalid URL, DOWN"
    end

    it "invalid file format as response" do
      response = 123
      s3.expects(:get_object).with(bucket: 'a-bucket', key: 'key', version_id: 'version_id').
        returns(fake_response(response))
      e = assert_raises(ActiveRecord::RecordInvalid) do
        group.read
      end
      e.message.must_equal "Validation failed: Url Invalid URL, no implicit conversion of Integer into String"
    end
  end
end
