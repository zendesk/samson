require 'zendesk/deployment'
require 'zendesk/deployment/migrations'
require 'zendesk/deployment/airbrake'

set :application, 'samson'
set :repository,  'git@github.com:zendesk/samson'
set :environments, [:staging, :pod3]
set :ruby_version, '2.0.0'
set :require_tag?, false
set :email_notification, ['deploys@zendesk.com', 'samson@zendesk.flowdock.com', 'epahl@zendesk.com']
set :user, 'deploy'
set :check_for_pending_migrations?, false

namespace :deploy do
  task :restart do
    sudo "/etc/init.d/puma.samson restart"
  end

  task :start do
    sudo "/etc/init.d/puma.samson start"
  end

  task :stop do
    sudo "/etc/init.d/puma.samson stop"
  end
end

namespace :samson do
  set :config_files, %w( database.yml )

  task :update_symlinks do
    # deploy_to defaults to /data/#{application}
    run "ln -nfs #{deploy_to}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{deploy_to}/config/.env #{release_path}/.env"
    run "(test -e #{deploy_to}/config/newrelic.yml && ln -nfs #{deploy_to}/config/newrelic.yml #{release_path}/config/) || true"

    run "cd #{release_path} && rm -rf log && ln -s #{deploy_to}/log log"
    run "mkdir -p #{deploy_to}/cached_repos && cd #{release_path} && rm -rf cached_repos && ln -s #{deploy_to}/cached_repos cached_repos"
  end

  namespace :assets do
    task :precompile do
      run "cd #{release_path} && bundle exec rake assets:precompile"
    end
  end
end

# Need to use before, or else this won't run in time.
before 'deploy:finalize_update', 'samson:update_symlinks'
after "deploy:update_code", "samson:assets:precompile"

def role_mapping(n)
  super.tap do |mapping|
    unless mapping.empty?
      mapping.merge!(:db => { :primary => true })
    end
  end
end
