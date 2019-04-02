# frozen_string_literal: true

require 'digest/sha2'
require 'large_object_store'

module Samson
  module Secrets
    module Manager
      ID_PARTS = [:environment_permalink, :project_permalink, :deploy_group_permalink, :key].freeze
      ID_PART_SEPARATOR = "/"
      SECRET_ID_REGEX = %r{[\w\/-]+}.freeze
      SECRET_LOOKUP_CACHE = 'secret_lookup_cache_v3'
      SECRET_LOOKUP_CACHE_MUTEX = Mutex.new
      VALUE_HASHED_BASE = Digest::SHA2.hexdigest("#{Samson::Application.config.secret_key_base}usedforhashing")

      def self.allowed_project_prefixes(user)
        allowed = user.administrated_projects.pluck(:permalink).sort
        allowed.unshift 'global' if user.admin?
        allowed
      end

      BACKEND = ENV.fetch('SECRET_STORAGE_BACKEND', 'Samson::Secrets::DbBackend').constantize

      class << self
        def write(id, data)
          return false unless id.match?(/\A#{SECRET_ID_REGEX}\z/)
          return false if data.blank? || data[:value].blank?
          result = backend.write(id, data)
          modify_lookup_cache { |c| c[id] = lookup_cache_value(data) }
          result
        end

        # reads a single id and raises ActiveRecord::RecordNotFound if it is not found
        def read(id, *args, include_value: false)
          data = backend.read(id, *args) || raise(ActiveRecord::RecordNotFound)
          data.delete(:value) unless include_value
          data
        end

        def history(id, include_value: false, **options)
          history = backend.history(id, options) || raise(ActiveRecord::RecordNotFound)
          unless include_value
            last_value = nil
            history.fetch(:versions).each_value do |data|
              current_value = data[:value]
              data[:value] = (last_value == current_value ? "(unchanged)" : "(changed)")
              last_value = current_value
            end
          end
          history
        end

        def revert(id, to:, user:)
          old = read(id, to, include_value: true)
          old[:user_id] = user.id
          write(id, old)
        end

        # useful for console sessions
        def move(from, to)
          copy(from, to)
          delete(from)
        end

        # useful for console sessions
        def copy(from, to)
          raise "#{to} already exists" if exist?(to)

          old = read(from, include_value: true)

          old[:user_id] = old.delete(:creator_id)
          write(to, old)

          old[:user_id] = old.delete(:updater_id)
          write(to, old)
        end

        # useful for console sessions
        # copies secrets over to new project, needs cleanup of old secrets once project is deployed everywhere
        # since otherwise in the meantime existing deploys would be unable to restart due to missing secrets
        def rename_project(from_project, to_project)
          id_parts = ids.map { |id| parse_id(id) }
          id_parts.select! { |parts| parts.fetch(:project_permalink) == from_project }
          id_parts.each do |parts|
            copy(generate_id(parts), generate_id(parts.merge(project_permalink: to_project)))
          end
          id_parts.size
        end

        def exist?(id)
          backend.read_multi([id]).values.map(&:nil?) == [false]
        end

        # reads multiple ids from the backend into a hash, not raising on missing
        # [a, b, c] -> {a: 1, c: 2}
        def read_multi(ids, include_value: false)
          data = backend.read_multi(ids)
          data.each_value { |s| s.delete(:value) } unless include_value
          data
        end

        def delete(id)
          result = backend.delete(id)
          modify_lookup_cache { |c| c.delete(id) }
          result
        end

        def ids
          lookup_cache.keys
        end

        def shareable_keys
          ids.map do |id|
            parts = Samson::Secrets::Manager.parse_id(id)
            parts.fetch(:key) if parts.fetch(:project_permalink) == "global"
          end.compact.uniq.sort
        end

        def filter_ids_by_value(ids, value)
          value_hashed = hash_value(value)
          lookup_cache.slice(*ids).select { |_, v| v.fetch(:value_hashed) == value_hashed }.keys
        end

        def backend
          BACKEND
        end

        def generate_id(data)
          ID_PARTS.map { |k| data.fetch(k) }.join(ID_PART_SEPARATOR)
        end

        def parse_id(id)
          ID_PARTS.zip(id.split(ID_PART_SEPARATOR, ID_PARTS.size)).to_h
        end

        def sharing_grants?
          ENV['SECRET_STORAGE_SHARING_GRANTS']
        end

        def lookup_cache
          SECRET_LOOKUP_CACHE_MUTEX.synchronize { fetch_lookup_cache }
        end

        def expire_lookup_cache
          cache.delete(SECRET_LOOKUP_CACHE)
        end

        private

        def fetch_lookup_cache
          cache.fetch(SECRET_LOOKUP_CACHE) do
            backend.ids.each_slice(1000).each_with_object({}) do |slice, all|
              read_multi(slice, include_value: true).each do |id, secret|
                all[id] = lookup_cache_value(secret)
              end
            end
          end
        end

        def cache
          @cache ||= LargeObjectStore.wrap(Rails.cache)
        end

        def lookup_cache_value(secret)
          {
            deprecated_at: secret[:deprecated_at],
            value_hashed: hash_value(secret.fetch(:value)),
            visible: secret[:visible]
          }
        end

        def hash_value(value)
          Digest::SHA2.hexdigest("#{VALUE_HASHED_BASE}#{value}").first(10)
        end

        def modify_lookup_cache
          SECRET_LOOKUP_CACHE_MUTEX.synchronize do
            content = fetch_lookup_cache
            yield content
            cache.write(SECRET_LOOKUP_CACHE, content)
          end
        end
      end
    end
  end
end
