# frozen_string_literal: true
require 'attr_encrypted'

module AttrEncryptedSupport
  ENCRYPTION_KEY = Rails.application.secrets.secret_key_base[0...32]
  ENCRYPTION_KEY_SHA = Digest::SHA2.hexdigest(Rails.application.secrets.secret_key_base)

  def self.included(base)
    base.send :before_validation, :store_encryption_key_sha
    base.extend ColumnHack
    base.extend Defaults
  end

  private

  # store the key so we have the possibility of decrypting when rotating keys
  def store_encryption_key_sha
    self.encryption_key_sha = ENCRYPTION_KEY_SHA
  end

  # use the same defaults everywhere
  module Defaults
    def attr_encrypted(column)
      super(column, key: ENCRYPTION_KEY, algorithm: 'aes-256-cbc')
    end
  end

  # A hack to make attr_encrypted always behave the same even when loaded without a database being present.
  # On load it checks if the column exists and then defined attr_accessors if they do not.
  # Reproduce with:
  # CI=1 RAILS_ENV=test TEST=test/lib/samson/secrets/db_backend_test.rb rake db:drop db:create default
  #
  # https://github.com/attr-encrypted/attr_encrypted/issues/226
  module ColumnHack
    def attr_encrypted(column, *)
      super
      bad = [
        :"encrypted_#{column}_iv",
        :"encrypted_#{column}_iv=",
        :"encrypted_#{column}",
        :"encrypted_#{column}="
      ]
      (instance_methods & bad).each { |m| undef_method m }
    end
  end
end
