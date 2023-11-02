# -*- encoding: utf-8 -*-
# stub: vault 0.12.0 ruby lib

Gem::Specification.new do |s|
  s.name = "vault".freeze
  s.version = "0.12.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Seth Vargo".freeze]
  s.bindir = "exe".freeze
  s.date = "2021-07-13"
  s.description = "Vault is a Ruby API client for interacting with a Vault server.".freeze
  s.email = ["sethvargo@gmail.com".freeze]
  s.files = [".gitignore".freeze, ".rspec".freeze, ".travis.yml".freeze, "CHANGELOG.md".freeze, "Gemfile".freeze, "LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "lib/vault.rb".freeze, "lib/vault/api.rb".freeze, "lib/vault/api/approle.rb".freeze, "lib/vault/api/auth.rb".freeze, "lib/vault/api/auth_tls.rb".freeze, "lib/vault/api/auth_token.rb".freeze, "lib/vault/api/help.rb".freeze, "lib/vault/api/kv.rb".freeze, "lib/vault/api/logical.rb".freeze, "lib/vault/api/secret.rb".freeze, "lib/vault/api/sys.rb".freeze, "lib/vault/api/sys/audit.rb".freeze, "lib/vault/api/sys/auth.rb".freeze, "lib/vault/api/sys/health.rb".freeze, "lib/vault/api/sys/init.rb".freeze, "lib/vault/api/sys/leader.rb".freeze, "lib/vault/api/sys/lease.rb".freeze, "lib/vault/api/sys/mount.rb".freeze, "lib/vault/api/sys/policy.rb".freeze, "lib/vault/api/sys/seal.rb".freeze, "lib/vault/client.rb".freeze, "lib/vault/configurable.rb".freeze, "lib/vault/defaults.rb".freeze, "lib/vault/encode.rb".freeze, "lib/vault/errors.rb".freeze, "lib/vault/persistent.rb".freeze, "lib/vault/persistent/connection.rb".freeze, "lib/vault/persistent/pool.rb".freeze, "lib/vault/persistent/timed_stack_multi.rb".freeze, "lib/vault/request.rb".freeze, "lib/vault/response.rb".freeze, "lib/vault/vendor/connection_pool.rb".freeze, "lib/vault/vendor/connection_pool/timed_stack.rb".freeze, "lib/vault/vendor/connection_pool/version.rb".freeze, "lib/vault/version.rb".freeze, "vault.gemspec".freeze]
  s.homepage = "https://github.com/hashicorp/vault-ruby".freeze
  s.licenses = ["MPL-2.0".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Vault is a Ruby API client for interacting with a Vault server.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<aws-sigv4>.freeze, [">= 0"])
      s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_development_dependency(%q<pry>.freeze, [">= 0"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 12.0"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.5"])
      s.add_development_dependency(%q<yard>.freeze, [">= 0"])
      s.add_development_dependency(%q<webmock>.freeze, ["~> 2.3"])
    else
      s.add_dependency(%q<aws-sigv4>.freeze, [">= 0"])
      s.add_dependency(%q<bundler>.freeze, [">= 0"])
      s.add_dependency(%q<pry>.freeze, [">= 0"])
      s.add_dependency(%q<rake>.freeze, ["~> 12.0"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.5"])
      s.add_dependency(%q<yard>.freeze, [">= 0"])
      s.add_dependency(%q<webmock>.freeze, ["~> 2.3"])
    end
  else
    s.add_dependency(%q<aws-sigv4>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, ["~> 12.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.5"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
    s.add_dependency(%q<webmock>.freeze, ["~> 2.3"])
  end
end
