# frozen_string_literal: true
# https://github.com/rails/rails/issues/29067
# can be removed if this works:
# Rails.cache.with_local_cache { Rails.cache.write('xxx', true, unless_exist: true)  }
ActiveSupport::Cache::Strategy::LocalCache::LocalStore.prepend(Module.new do
  def clear(*)
    super()
  end
end)
