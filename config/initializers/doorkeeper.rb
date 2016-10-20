# frozen_string_literal: true

# Doorkeeper (https://github.com/doorkeeper-gem/doorkeeper) is the engine
# that secures /api. It uses OAuth and the OAuth2 gem can be used to interact
# with the samson api.





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
    request.env['warden'].user
  end

  default_scopes :default
  base_controller 'DoorkeeperBaseController'
end
