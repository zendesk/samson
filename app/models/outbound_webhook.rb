# frozen_string_literal: true

require 'faraday'

class OutboundWebhook < ActiveRecord::Base
  AUTH_TYPES = ["None", "Basic", "Token", "Bearer"].freeze

  audited

  has_many :outbound_webhook_stages, dependent: nil, inverse_of: :outbound_webhook
  has_many :stages, through: :outbound_webhook_stages, dependent: nil, inverse_of: :outbound_webhooks

  validate :validate_url_is_absolute
  validate :validate_auth
  validate :validate_name_for_global
  validates :name, uniqueness: {case_sensitive: false}, if: :global?

  before_destroy :ensure_unused

  scope :active, -> { where(disabled: false) }

  def deliver(deploy, output)
    prefix = "Webhook notification:"

    output.puts "#{prefix} sending to #{url} ..."
    response = post_hook(deploy)

    if response.success?
      if status_path?
        if status_url = JSON.parse(response.body)[status_path]
          output.puts "#{prefix} polling #{status_url} ..."
          poll_status_url(status_url) { |body| output.puts "#{prefix} #{body}" }
          output.puts "#{prefix} succeeded"
        else
          raise Samson::Hooks::UserError, "#{prefix} response did not include status url at #{status_path}"
        end
      else
        output.puts "#{prefix} succeeded"
      end
    else
      Rails.logger.error "Outbound Webhook Error #{id} #{url} #{response.body}"
      raise(
        Samson::Hooks::UserError,
        "#{prefix} failed #{response.status}\n#{response.body.to_s.truncate(100)}"
      )
    end
  rescue StandardError => e # Timeout or SSL
    raise e if e.is_a?(Samson::Hooks::UserError)
    raise Samson::Hooks::UserError, "#{prefix} failed #{e.class}"
  end

  def self.deploy_as_json(deploy)
    deploy.as_json.merge(
      "deploy_groups" => deploy.stage.deploy_groups.as_json,
      "project" => deploy.project.as_json,
      "stage" => deploy.stage.as_json,
      "user" => deploy.user.as_json
    )
  end

  def ssl?
    url.start_with?("https://") && !insecure?
  end

  def as_json(*)
    super(except: [:password])
  end

  private

  def poll_period
    @poll_period ||= Integer(ENV['OUTBOUND_WEBHOOK_POLL_PERIOD'] || '30')
  end

  def post_hook(deploy)
    connection.post url do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = self.class.deploy_as_json(deploy).to_json
    end
  end

  # loop forever, with sleeping in between, until user cancels the deploy or deploy times out
  def poll_status_url(url)
    loop do
      response = connection.get(url)
      yield response.body
      if response.success?
        break if response.status != 202
      else
        raise Samson::Hooks::UserError, "error polling status endpoint"
      end
      sleep poll_period
    end
  end

  def connection
    Faraday.new(ssl: {verify: !insecure}) do |connection|
      connection.request  :url_encoded
      connection.adapter  Faraday.default_adapter

      case auth_type
      when "None" # noop
      when "Basic" then connection.request :authorization, :basic, username, password
      when "Bearer", "Token" then connection.request :authorization, auth_type, password
      else raise ArgumentError, "Unsupported auth_type #{auth_type.inspect}"
      end
    end
  end

  def validate_auth
    case auth_type
    when "None" # noop
    when "Basic" then errors.add :username, "and password must be set" if !username? || !password?
    when "Bearer", "Token" then errors.add :password, "must be set" unless password?
    else errors.add(:auth_type, "unknown, supported types are #{AUTH_TYPES.to_sentence}")
    end
  end

  def validate_url_is_absolute
    errors.add(:url, "must begin with http:// or https://") unless url.start_with?("http://", "https://")
  end

  def ensure_unused
    return if outbound_webhook_stages.empty?
    errors.add :base, 'Can only delete when unused.'
    throw :abort
  end

  def validate_name_for_global
    if global?
      errors.add(:name, "must be present") unless name?
    else
      self.name = name.presence # prevent unique index failing on blank
      errors.add(:name, "must be blank for non-global webhooks") if name?
    end
  end
end
Samson::Hooks.load_decorators(OutboundWebhook)
