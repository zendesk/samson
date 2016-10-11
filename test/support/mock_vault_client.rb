# frozen_string_literal: true

Samson::Secrets::VaultClient.class_eval do
  def logical
    @logical ||= Vault::Logical.new
  end

  def self.vault_response_object(data)
    Response.new(data)
  end

  def self.client
    @client ||= new
  end

  def initialize
    @expected = {}
    @set = {}
  end

  def list(key)
    @expected.delete("list-#{key}") || raise(KeyError, "list-#{key} not registered")
  end

  def read(key)
    vault_instance(key)
    Response.new(@expected.delete(key) || raise(KeyError, "#{key} not registered"))
  end

  def delete(key)
    write(key, nil)
  end

  def write(key, body)
    vault_instance(key)
    @set[key] = body
    true
  end

  def config_for(deploy_group_name)
    {
      'vault_address' => 'https://test.hvault.server',
      'tls_verify' => false, "vault_instance": deploy_group_name
    }
  end

  def vault_instance(key)
    deploy_group = SecretStorage.parse_secret_key(key.split('/', 3).last).fetch(:deploy_group_permalink)
    vaults = ['pod2', 'foo', 'group', 'global']
    unless vaults.include?(deploy_group)
      raise(KeyError, "no vault_instance configured for deploy group #{deploy_group}")
    end
  end

  # test hooks
  def clear
    @set.clear
    @expected.clear
  end

  def expect(key, value)
    @expected[key] = value
  end

  attr_reader :set

  def verify!
    @expected.keys.must_equal([], "Expected calls missed: #{@expected.keys}")
  end

  class Response
    attr_accessor :lease_id, :lease_duration, :renewable, :data, :auth
    def initialize(data)
      self.lease_id = nil
      self.lease_duration = nil
      self.renewable = nil
      self.auth = nil
      self.data = data
    end

    def to_h
      instance_values.symbolize_keys
    end
  end
end
