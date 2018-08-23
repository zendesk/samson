# frozen_string_literal: true
class GithubStatus
  Status = Struct.new(:context, :latest_status) do
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

  def initialize(repo, ref, github: GITHUB, cache: Rails.cache)
    @github = github
    @cache = cache
    @repo = repo
    @ref = ref
    @state = nil
  end

  def state
    status_response ? status_response.state : "missing"
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

  def missing?
    state == "missing"
  end

  def statuses
    @statuses ||= begin
      return [] if status_response.nil?

      status_response.statuses.group_by(&:context).map do |context, statuses|
        Status.new(context, statuses.max_by { |status| status.created_at.to_i })
      end
    end
  end

  private

  def status_response
    return @status_response if defined?(@status_response)

    cache_key = [self.class.to_s, @repo, @ref]

    @status_response = @cache.read(cache_key)

    # Fetch the data if the cache returned nil.
    @status_response ||= begin
      @github.combined_status(@repo, @ref)
    rescue Octokit::Error
      nil
    end

    # Don't cache pending statuses, since we expect updates soon.
    unless @status_response&.state == "pending"
      @cache.write(cache_key, @status_response, expires_in: 1.hour)
    end

    @status_response
  end
end
