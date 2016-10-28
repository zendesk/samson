# frozen_string_literal: true
# https://github.com/rails/rails/issues/24028
# can be removed if a deploy on osx in development mode without eager load works
ActiveSupport::Dependencies::Interlock.class_eval do
  undef loading
  def loading
    yield
  end
end
