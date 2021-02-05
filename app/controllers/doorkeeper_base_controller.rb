# frozen_string_literal: true
class DoorkeeperBaseController < ActionController::Base
  include CurrentUser # used in the header template
  layout 'application'
  protect_from_forgery with: :exception

  # This is a hack to prevent doorkeeper from overriding templates.
  # There is a builtin way to do this but it involves preloading models, which we are trying to avoid
  def self.layout(_x)
  end
end
