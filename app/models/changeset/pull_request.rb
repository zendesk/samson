class Changeset::PullRequest
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
    "https://github.com/#{repo}/pulls/#{number}"
  end
end
