namespace :deploys do
  def env
    @env ||= HashWithIndifferentAccess.new(Hash(ENV))
  end

  def deploy
    @deploy ||= begin
      deploy_id = env.delete(:DEPLOY_ID)
      raise Exception.new("Usage: rake <task> DEPLOY_ID=<deploy_id>") unless deploy_id =~ /^\d+$/
      Deploy.find(deploy_id)
    end
  end

  def exit_with_status
    if deploy.job.succeeded?
      puts "#{deploy.stage.name} deploy succedded"
      exit 0
    else
      puts "#{deploy.stage.name} deploy failed"
      exit 1
    end
  end

  desc "Stop deploys that remain too long in a pending state"
  task :stop_expired_deploys => :environment do
    BuddyCheck.stop_expired_deploys
  end

  desc "Start a pending deploy"
  task :start_pending_deploy => :environment do
    raise Exception.new("Deploy not in the pending state") unless deploy.pending?
    puts "Executing deploy for #{deploy.stage.project.name} #{deploy.stage.name}..."
    deploy.pending_start!
    job_execution = JobExecution.find_by_id(deploy.job.id)
    job_execution.wait!
    exit_with_status
  end

  desc "Check if a deploy was successful"
  task :check_success => :environment do
    exit_with_status
  end
end
