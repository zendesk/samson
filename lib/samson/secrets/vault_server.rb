# frozen_string_literal: true
require 'vault'

module Samson
  module Secrets
    class VaultServer < ActiveRecord::Base
      PREFIX = 'secret/apps/'

      has_paper_trail skip: [:updated_at, :created_at]
      include AttrEncryptedSupport
      self.table_name = :vault_servers
      ADDRESS_PATTERN = /\Ahttps?:\/\//

      DEFAULT_CLIENT_OPTIONS = {
        use_ssl: true,
        timeout: 5,
        ssl_timeout: 3,
        open_timeout: 3,
        read_timeout: 2
      }.freeze

      attr_encrypted :token
      validates :name, presence: true, uniqueness: true
      validates :address, presence: true, format: ADDRESS_PATTERN
      validate :validate_cert
      validate :validate_connection

      def cert_store
        return unless ca_cert.present?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_cert))
        cert_store
      end

      def client
        Vault::Client.new(
          DEFAULT_CLIENT_OPTIONS.merge(
            ssl_verify: tls_verify,
            token: token,
            address: address,
            ssl_cert_store: cert_store
          )
        )
      end

      private

      def validate_cert
        cert_store
      rescue OpenSSL::OpenSSLError
        errors.add :ca_cert, "is invalid: #{$!.message}"
      end

      def validate_connection
        return if errors.any? # no need to blow up / wait if we know things are invalid
        client.logical.list(PREFIX)
      rescue Vault::VaultError
        errors.add :base, "Unable to connect to server:\n#{$!.message}"
      end
    end
  end
end
