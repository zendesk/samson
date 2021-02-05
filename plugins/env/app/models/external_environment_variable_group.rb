# frozen_string_literal: true
require 'aws-sdk-s3'

class ExternalEnvironmentVariableGroup < ActiveRecord::Base
  S3_URL_REGEX = /\Ahttps:\/\/([^.]+)\.s3\.amazonaws\.com\/([\w\W]+)\Z/i.freeze
  S3_URL_FORMAT = "https://#{ENV['EXTERNAL_ENV_GROUP_S3_BUCKET']}.s3.amazonaws.com/[key]?versionId=[version_id]"
  HELP_TEXT = ENV.fetch(
    "EXTERNAL_ENV_GROUP_HELP_TEXT",
    "Use external service to manage environment variable groups"
  ).html_safe
  audited
  default_scope -> { order(:name) }

  belongs_to :project, inverse_of: :external_environment_variable_groups
  validates :name, :url, presence: true
  validates :url, format: {
    with: S3_URL_REGEX,
    message: "Invalid format, valid url format is #{S3_URL_FORMAT}"
  }
  validate :validate_s3_url

  def read
    key, bucket, version_id = resolve_s3_url
    default_bucket = ENV.fetch 'EXTERNAL_ENV_GROUP_S3_BUCKET'
    default_region = ENV.fetch 'EXTERNAL_ENV_GROUP_S3_REGION'
    dr_bucket      = ENV['EXTERNAL_ENV_GROUP_S3_DR_BUCKET']
    dr_region      = ENV['EXTERNAL_ENV_GROUP_S3_DR_REGION']
    Samson::Retry.with_retries(Aws::S3::Errors::ServiceError, 3) do
      response =
        begin
          s3_client = Aws::S3::Client.new(region: default_region)
          s3_client.get_object(bucket: default_bucket, key: key, version_id: version_id)
        rescue Aws::S3::Errors::NoSuchKey
          raise "key \"#{key}\" does not exist in bucket #{bucket}!"
        rescue Aws::S3::Errors::ServiceError => e
          raise e if !dr_bucket || !dr_region
          s3_client = Aws::S3::Client.new(region: dr_region)
          s3_client.get_object(bucket: dr_bucket, key: key, version_id: version_id)
        end
      # loads both json and yaml
      # Refer https://stackoverflow.com/questions/24608600/is-it-safe-to-parse-json-with-yaml-load
      YAML.safe_load response.body.read
    end
  end

  def self.configured?
    ENV['EXTERNAL_ENV_GROUP_S3_BUCKET'] && ENV['EXTERNAL_ENV_GROUP_S3_REGION']
  end

  private

  def validate_s3_url
    return if errors[:url].any?
    key, bucket = resolve_s3_url

    if key.blank? || bucket.blank?
      errors.add(:url, 'Invalid: unable to get s3 key or bucket')
      return
    end

    default_bucket = ENV.fetch('EXTERNAL_ENV_GROUP_S3_BUCKET')
    if bucket != default_bucket
      errors.add(:url, "Invalid: bucket must be #{default_bucket}")
      return
    end

    read
  rescue StandardError => e
    errors.add(:url, "Invalid: #{e.message}")
  end

  # Resolves the S3 key and bucket name from URL
  def resolve_s3_url
    parsed_url = URI.parse url.to_s

    key = parsed_url.path.to_s[1..]
    bucket = parsed_url.host.to_s.chomp ".s3.amazonaws.com"

    params = (URI.decode_www_form parsed_url.query.to_s).to_h
    version_id = params["versionId"]
    [key, bucket, version_id]
  end
end
