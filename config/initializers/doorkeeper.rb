# frozen_string_literal: true
# do not auto initialize all the models
# will make rails runner fail because the models were preloaded
module Doorkeeper
  autoload :AccessGrant, 'doorkeeper/orm/active_record/access_grant'
  autoload :AccessToken, 'doorkeeper/orm/active_record/access_token'
  autoload :Application, 'doorkeeper/orm/active_record/application'

  module Orm
    module ActiveRecord
      def self.initialize_models!
      end
    end
  end
end

Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    env['warden'].user
  end

  default_scopes :default
  base_controller 'DoorkeeperBaseController'
end
