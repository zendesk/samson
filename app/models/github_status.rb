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

  attr_reader :state, :statuses

  def initialize(state, statuses)
    @state = state
    @statuses = statuses
  end

  def self.for_reference(repo, ref)
    # Fetch the data if the cache returned nil.
    response ||= begin
      GITHUB.combined_status(repo, ref)
    rescue Octokit::Error
      nil
    end

    # Fall back to a "missing" status.
    return new("missing", []) if response.nil?

    statuses = response.statuses.group_by(&:context).map do |context, statuses|
      Status.new(context, statuses.max_by { |status| status.created_at.to_i })
    end

    new(response.state, statuses)
  end

  def self.for_release(release)
    # Base the cache key on the Release, so that an update to it effectively
    # clears the cache.
    cache_key = [name, release, "v2"]

    status = Rails.cache.read(cache_key)
    status ||= for_reference(release.project.repository_path, release.commit)

    # Don't cache pending statuses, since we expect updates soon.
    unless status.statuses.any?(&:pending?)
      Rails.cache.write(cache_key, status, expires_in: 1.hour)
    end

    status
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
end
