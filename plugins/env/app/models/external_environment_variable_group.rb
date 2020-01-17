# frozen_string_literal: true
require 'aws-sdk-s3'

class ExternalEnvironmentVariableGroup < ActiveRecord::Base
  S3_URL_REGEX = /https:\/\/([^.]+)\.s3\.amazonaws\.com\//i.freeze
  S3_URL_FORMAT = "https://[bucket].s3.amazonaws.com/[key]?versionId=[version_id]"
  HELP_TEXT = ENV.fetch(
    "EXTERNAL_ENV_GROUP_HELP_TEXT",
    "Use external service to manage environment variable groups"
  ).html_safe
  attr_accessor :key, :bucket, :version_id
  audited
  default_scope -> { order(:name) }

  belongs_to :project, inverse_of: :external_environment_variable_groups
  validates :name, :url, presence: true
  validates :url, format: {
    with: S3_URL_REGEX,
    message: "Invalid format, valid url format is #{S3_URL_FORMAT}"
  }
  validate :validate_s3_url
  after_find :resolve_s3_url

  def external_service_read_with_failover
    default_bucket = ENV.fetch 'EXTERNAL_ENV_GROUP_S3_BUCKET'
    default_region = ENV.fetch 'EXTERNAL_ENV_GROUP_S3_REGION'
    dr_bucket      = ENV['EXTERNAL_ENV_GROUP_S3_DR_BUCKET']
    dr_region      = ENV['EXTERNAL_ENV_GROUP_S3_DR_REGION']
    if default_bucket != bucket && dr_bucket != bucket
      buckets = [default_bucket, dr_bucket].compact
      raise "Invalid s3 bucket, acceptable buckets are #{buckets.join(',')}"
    end
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
      YAML.safe_load response.body.read
    end
  end

  private

  def validate_s3_url
    resolve_s3_url
    if key.blank? || bucket.blank?
      errors.add(:url, 'Invalid URL, unable to get s3 key or bucket')
      return
    end
    external_service_read_with_failover
  rescue StandardError => e
    errors.add(:url, "Invalid URL, #{e.message}")
  end

  def resolve_s3_url
    return unless url
    parsed_url = URI.parse url.to_s
    @key = parsed_url.path.to_s[1..-1]
    @bucket = parsed_url.host.to_s.chomp ".s3.amazonaws.com"
    params = (URI.decode_www_form parsed_url.query.to_s).to_h
    @version_id = params["versionId"]
  end
end
