require 'zendesk/deployment'
require 'zendesk/deployment/migrations'

set :application, 'pusher'
set :repository,  'git@github.com:zendesk/pusher'
set :environments, [:staging, :pod3]
set :ruby_version, '2.1.0'
set :require_tag?, false
set :email_notification, ['deploys@zendesk.com', 'pusher@zendesk.flowdock.com', 'epahl@zendesk.com']
set :user, 'deploy'

namespace :deploy do
  task :restart do
    sudo "/etc/init.d/puma.pusher restart"
  end

  task :start do
    sudo "/etc/init.d/puma.pusher start"
  end

  task :stop do
    sudo "/etc/init.d/puma.pusher stop"
  end
end

namespace :pusher do
  set :config_files, %w( database.yml )

  task :update_symlinks do
    config_files.each do |file|
      run "ln -nfs /etc/zendesk/pusher/#{file} #{release_path}/config/#{file}"
    end
    # deploy_to defaults to /data/#{application}
    run "ln -nfs #{deploy_to}/config/.env #{release_path}/.env"
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
before 'deploy:finalize_update', 'pusher:update_symlinks'
after "deploy:update_code","pusher:assets:precompile"

def role_mapping(n)
  super.tap do |mapping|
    unless mapping.empty?
      mapping.merge!(:db => { :primary => true })
    end
  end
end
