# frozen_string_literal: true
require 'attr_encrypted'

module AttrEncryptedSupport
  encryption_key_raw = (ENV['ATTR_ENCRYPTED_KEY'] || Rails.application.secrets.secret_key_base)
  ENCRYPTION_KEY = encryption_key_raw[0...32]
  ENCRYPTION_KEY_SHA = Digest::SHA2.hexdigest(encryption_key_raw)

  def self.included(base)
    base.send :before_validation, :store_encryption_key_sha
    base.extend ClassMethods
  end

  def as_json(except: [], **options)
    except += [
      :encryption_key_sha,
      *self.class.encrypted_attributes.keys.flat_map do |column|
        [column, :"encrypted_#{column}_iv", :"encrypted_#{column}"]
      end
    ]
    super(except: except, **options)
  end

  private

  # store the key so we have the possibility of decrypting when rotating keys
  def store_encryption_key_sha
    self.encryption_key_sha = ENCRYPTION_KEY_SHA
  end

  # use the same defaults everywhere
  module ClassMethods
    def attr_encrypted(column)
      super(column, key: ENCRYPTION_KEY, algorithm: 'aes-256-cbc')
    end
  end
end
