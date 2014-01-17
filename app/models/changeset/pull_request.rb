class Changeset::PullRequest
  # Matches a section heading named "Risks".
  RISKS_SECTION = /#+\s+Risks.*\n/i

  def self.find(repo, number)
    github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    data = github.pull_request(repo, number)

    new(repo, data)
  end

  attr_reader :repo

  def initialize(repo, data)
    @repo, @data = repo, data
  end

  delegate :number, :title, :additions, :deletions, to: :@data

  def url
    "https://github.com/#{repo}/pull/#{number}"
  end

  def users
    users = [@data.user, @data.merged_by]
    users.map {|user| Changeset::GithubUser.new(user) }.uniq
  end

  def risky?
    risks.present?
  end

  def risks
    @risks ||= parse_risks!
  end

  private

  def parse_risks!
    parts = @data.body.split(RISKS_SECTION, 2)

    if parts.size == 1
      nil
    else
      parts[1] && parts[1].strip
    end
  end
end
