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

    stages = @deploy.project.stages
    production_stages, staging_stages = stages.partition(&:production?)
    scope = Deploy.succeeded.where(jobs: {commit: @deploy.commit}).reorder(:id)
    return {} unless @deploy == scope.where(stage: production_stages).first!

    first_staging_deploy = scope.find_by(stage: staging_stages)

    times = {}
    if time = pr_production
      times[:pr_production] = time
    end
    if time = staging_production(first_staging_deploy)
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
  # (this can end up being negative if production was done before staging)
  def staging_production(staging)
    return nil unless staging
    @deploy.updated_at.to_i - staging.updated_at.to_i
  end
end
