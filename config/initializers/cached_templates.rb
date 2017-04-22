# frozen_string_literal: true
# Samson often gets slow because deploys are IO heavy
# avoid loading 10+ templates per page render from disk
# test by booting the server, requesting the homepage and then sudo chmod -R -r app/views and refresh
unless Rails.env.development?
  class ActionView::PathResolver
    class File < ::File
      def self.binread(path)
        (@@binread_cache ||= {})[path] ||= super(path)
      end
    end

    prepend(Module.new do
      def find_template_paths(query)
        (@@find_template_paths_cache ||= {})[query] ||= super
      end
    end)
  end
end
