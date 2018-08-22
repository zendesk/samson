class GithubStatus
  class Status < Struct.new(:context, :latest_status)
    def state
      latest_status.state
    end

    def description
      latest_status.description
    end

    def url
      latest_status.target_url
    end

    def success?
      state == "success"
    end

    def failure?
      state == "failure"
    end

    def pending?
      state == "pending"
    end
  end

  def initialize(repo, ref, github: GITHUB)
    @github = github
    @repo = repo
    @ref = ref
    @state = nil
  end

  def state
    status_response ? status_response.state : "missing"
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
    @statuses ||= begin
      return [] if status_response.nil?

      status_response.statuses.group_by(&:context).map do |context, statuses|
        Status.new(context, statuses.max_by {|status| status.created_at.to_i })
      end
    end
  end

  private

  def status_response
    @status_response ||= @github.combined_status(@repo, @ref)
  rescue Octokit::Error
    nil
  end
end
