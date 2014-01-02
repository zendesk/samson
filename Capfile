require 'zendesk/deployment'

set :application, 'pusher'
set :repository,  'git@github.com:zendesk/pusher'
set :environments, [:staging, :pod3]
set :ruby_version, 'jruby'
set :require_tag?, false
set :email_notification, ['deploys@zendesk.com', 'epahl@zendesk.com']

namespace :pusher do
  set :config_files, %w( database.yml redis.yml )

  task :update_symlinks do
    config_files.each do |file|
      system "ln -nfs /etc/zendesk/pusher/#{file} #{release_path}/config/#{file}"
    end
    run "cd #{release_path} && rm -rf log && ln -s #{deploy_to}/log log"
  end
end

after "deploy:update_code","pusher:update_symlinks"
