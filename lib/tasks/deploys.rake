namespace :deploys do
  desc "Stop deploys that remain too long in a pending state"
  task :stop_expired_deploys => :environment do
    BuddyCheck.stop_expired_deploys
  end

  desc "Start a pending deploy"
  task :start_pending_deploy => :environment do
    env = HashWithIndifferentAccess.new(Hash(ENV))
    deploy_id = env.delete(:DEPLOY_ID)
    raise Exception.new("Usage: rake deploys:start_pending_deploy DEPLOY_ID=<deploy_id>") unless deploy_id =~ /^\d+$/
    deploy = Deploy.find(deploy_id)
    raise Exception.new("Deploy not in the pending state") unless deploy.pending?

    puts "Executing deploy for #{deploy.stage.project.name} #{deploy.stage.name}..."
    deploy.pending_start!
    job_execution = JobExecution.find_by_id(deploy.job.id)
    job_execution.wait!
  end
end
