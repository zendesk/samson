# do not use common assets from rails-assets, we already have them in rails
# http://stackoverflow.com/questions/7163264/rails-3-1-asset-pipeline-
module Sprockets
  module Paths
    SKIP_GEMS = ["rails-assets-jquery"]

    def append_path_with_rails_assets(path)
      append_path_without_rails_assets(path) unless SKIP_GEMS.any? { |gem| path.to_s.start_with?(Gem.loaded_specs[gem].full_gem_path) }
    end

    alias_method_chain :append_path, :rails_assets
  end
end
