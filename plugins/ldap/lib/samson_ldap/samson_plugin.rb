# frozen_string_literal: true
require 'omniauth-ldap'

module SamsonLdap
  class Engine < Rails::Engine
  end

  def self.enabled?
    Samson::EnvCheck.set?("AUTH_LDAP")
  end
end

Rails.application.config.assets.precompile << "auth/ldap.png"

Samson::Hooks.callback :omniauth_builder do |builder|
  if SamsonLdap.enabled?
    builder.provider OmniAuth::Strategies::LDAP,
      title: ENV["LDAP_TITLE"].presence,
      host: ENV["LDAP_HOST"].presence,
      port: ENV["LDAP_PORT"].presence,
      method: 'plain',
      base: ENV["LDAP_BASE"].presence,
      uid: ENV["LDAP_UID"].presence,
      bind_dn: ENV["LDAP_BINDDN"].presence,
      password: ENV["LDAP_PASSWORD"].presence
  end
end

Samson::Hooks.callback :omniauth_uid do |auth_hash|
  if auth_hash.provider == 'ldap' && SamsonLdap.enabled? && ENV['USE_LDAP_UID_AS_EXTERNAL_ID']
    uid_field = Rails.application.config.samson.ldap.uid
    uid = auth_hash.extra.raw_info.send(uid_field).presence || raise
    Array(uid).first
  end
end

Samson::Hooks.callback :omniauth_provider do
  'LDAP' if SamsonLdap.enabled?
end
