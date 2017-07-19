# frozen_string_literal: true
module SecretStorage
  ID_PARTS = [:environment_permalink, :project_permalink, :deploy_group_permalink, :key].freeze
  ID_PART_SEPARATOR = "/"

  def self.allowed_project_prefixes(user)
    allowed = user.administrated_projects.pluck(:permalink).sort
    allowed.unshift 'global' if user.admin?
    allowed
  end

  SECRET_ID_REGEX = %r{[\w\/-]+}
  SECRET_IDS_CACHE = 'secret_storage_keys'

  # keeps older lookups working
  DbBackend = Samson::Secrets::DbBackend
  HashicorpVault = Samson::Secrets::HashicorpVaultBackend

  BACKEND = ENV.fetch('SECRET_STORAGE_BACKEND', 'Samson::Secrets::DbBackend').constantize

  class << self
    def write(id, data)
      return false unless id =~ /\A#{SECRET_ID_REGEX}\z/
      return false if data.blank? || data[:value].blank?
      result = backend.write(id, data)
      modify_ids_cache { |c| c.push id unless c.include?(id) }
      result
    end

    # reads a single id and raises ActiveRecord::RecordNotFound if it is not found
    def read(id, include_value: false)
      data = backend.read(id) || raise(ActiveRecord::RecordNotFound)
      data.delete(:value) unless include_value
      data
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
      modify_ids_cache { |c| c.delete(id) }
      result
    end

    def ids
      Rails.cache.fetch(SECRET_IDS_CACHE) { backend.ids }
    end

    def shareable_keys
      ids.map do |id|
        parts = SecretStorage.parse_id(id)
        parts.fetch(:key) if parts.fetch(:project_permalink) == "global"
      end.compact
    end

    def filter_ids_by_value(*args)
      backend.filter_ids_by_value(*args)
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

    private

    def modify_ids_cache
      if cache = Rails.cache.read(SECRET_IDS_CACHE)
        yield cache
        Rails.cache.write(SECRET_IDS_CACHE, cache)
      end
    end
  end
end
