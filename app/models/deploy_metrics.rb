# frozen_string_literal: true

# Used to collect metrics of cycle time(elapsed time needed to deliver a project to production)
# Check out https://about.gitlab.com/2019/03/04/reduce-cycle-time/ for more details on cycle time
# The main objective for this is to gain more insight on the efficiency of the end-to-end project development process
# There are 2 key metrics:
# 1. PR - Production: this will show the time needed for a pull request to get deployed to production environment
# 2. Staging - Production: this will show the time needed to deliver from staging(non-production environment)
#                          to production environment.
class DeployMetrics
  def initialize(deploy)
    @deploy = deploy
  end

  def cycle_time
    return {} unless @deploy&.production && @deploy&.status == "succeeded"

    times = {}
    if time = pr_production
      times[:pr_production] = time
    end
    if time = staging_production
      times[:staging_production] = time
    end
    times
  end

  private

  # Calculated by averaging deployment end time minus pull requests' creation time
  def pr_production
    prs = @deploy.changeset.pull_requests
    return nil if prs.empty?

    prs.sum { |pr| @deploy.updated_at.to_i - pr.created_at.to_i } / prs.size
  end

  # Time it took from first staging deploy to finish until the first production deploy finished
  def staging_production
    stages = @deploy.project.stages
    production, staging = stages.partition(&:production?)

    scope = Deploy.successful.where(jobs: {commit: @deploy.commit}).reorder(:id)
    return nil unless first_staging_deploy = scope.where(stage: staging).first
    # should always exists since we have a check in cycle_time method
    first_production_deploy = scope.where(stage: production).first!

    first_production_deploy.updated_at.to_i - first_staging_deploy.updated_at.to_i
  end
end
