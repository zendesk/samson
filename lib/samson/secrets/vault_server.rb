# frozen_string_literal: true

module Samson
  module Secrets
    class VaultServer < ActiveRecord::Base
      has_paper_trail skip: [:updated_at, :created_at]
      include AttrEncryptedSupport
      self.table_name = :vault_servers
      ADDRESS_PATTERN = /\Ahttps?:\/\//

      attr_encrypted :token
      validates :name, presence: true, uniqueness: true
      validates :address, presence: true, format: ADDRESS_PATTERN
      validate :validate_cert

      def cert_store
        return unless ca_cert.present?
        cert_store = OpenSSL::X509::Store.new
        cert_store.add_cert(OpenSSL::X509::Certificate.new(ca_cert))
        cert_store
      end

      private

      def validate_cert
        cert_store
      rescue OpenSSL::OpenSSLError
        errors.add :ca_cert, "is invalid: #{$!.message}"
      end
    end
  end
end
