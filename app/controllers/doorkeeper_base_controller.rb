# frozen_string_literal: true
class DoorkeeperBaseController < ActionController::Base
  include CurrentUser
  # We need this because it's used in the header template
  layout 'application'

  before_action :authorize_super_admin!

  def self.layout(_x)
    # This is a hack to prevent doorkeeper from overriding templates.
    # There is a builtin way to do this but it involves preloading models
    # which we don't want to do.
  end
end
