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
    env['warden'].user || redirect_to(login_url)
  end

  default_scopes :default
  optional_scopes :read, :modify, :delete
  base_controller 'DoorkeeperBaseController'
end
