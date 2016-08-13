# frozen_string_literal: true
# angular-rails-templates does not work cleanly with new sprockets
# and spams warnings when booting rails
# https://github.com/pitr/angular-rails-templates/issues/143
Sprockets::Environment.class_eval do
  def register_engine(ext, klass, options = {})
    super(ext, klass, options.merge(silence_deprecation: true))
  end
end
