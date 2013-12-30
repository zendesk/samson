require 'zendesk/deployment'

set :application, 'zendesk_deploy_service'
set :repository,  'git@github.com:zendesk/zendesk_deploy_service'
set :environments, [:master1, :master2, :staging, :qa, :pod1, :pod2, :pod3]
set :ruby_version, 'jruby'
set :require_tag?, false
set :email_notification, ['deploys@zendesk.com', 'epahl@zendesk.com']

desc 'Select master15'
task :master15 do
  set :environment, 'master15'
  set :rails_env, 'production'            # Set the RAILS_ENV of this environment
  role :deploy, 'master15.rsc.zdsys.com'  # Give master15 the :deploy role
end

