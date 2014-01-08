require 'zendesk/deployment'

set :application, 'pusher'
set :repository,  'git@github.com:zendesk/pusher'
set :environments, [:staging, :pod3]
set :ruby_version, '2.0.0-p353'
set :require_tag?, false
set :email_notification, ['deploys@zendesk.com', 'epahl@zendesk.com']

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
    run "ln -nfs /data/pusher/config/.env #{release_path}/.env"
    run "cd #{release_path} && rm -rf log && ln -s #{deploy_to}/log log"
    run "mkdir -p #{deploy_to}/cached_repos && cd #{release_path} && rm -rf cached_repos && ln -s #{deploy_to}/cached_repos cached_repos"
  end
end

after "deploy:update_code","pusher:update_symlinks"
