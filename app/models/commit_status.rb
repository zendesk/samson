# frozen_string_literal: true
# Used to display all warnings/failures before user actually deploys
class CommitStatus
  def initialize(user_repo_part, reference)
    @repo = user_repo_part
    @reference = reference
  end

  def status
    combined_status.fetch(:state)
  end

  def status_list
    combined_status.fetch(:statuses).map(&:to_h)
  end

  private

  def combined_status
    @combined_status ||= begin
      GITHUB.combined_status(@repo, @reference).to_h
    rescue Octokit::NotFound
      {
        state: "failure",
        statuses: [{"state": "Reference", description: "'#{@reference}' does not exist"}]
      }
    end
  end
end
