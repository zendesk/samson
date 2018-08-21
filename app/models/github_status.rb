class GithubStatus
  class Status < Struct.new(:context, :latest_status)
    def success?
      latest_status.state == "success"
    end

    def failure?
      latest_status.state == "failure"
    end

    def pending?
      latest_status.state == "pending"
    end
  end

  def initialize(repo, ref, github: GITHUB)
    @github = github
    @repo = repo
    @ref = ref
  end

  def success?
    !missing? && statuses.all?(&:success?)
  end

  def failure?
    statuses.any?(&:failure?)
  end

  def pending?
    statuses.any?(&:pending?)
  end

  def missing?
    statuses.none?
  end

  def statuses
    response = @github.combined_status(@repo, @ref)

    statuses = response.statuses

    return [] if statuses.nil?

    statuses.group_by {|status| status.context }
      .map {|context, statuses|
        Status.new(context, statuses.max_by {|status| status.created_at.to_i })
      }
  rescue Octokit::Error
    # In case of error, fall back to not listing the statuses.
    []
  end
end
