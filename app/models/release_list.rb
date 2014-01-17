require 'octokit'

class ReleaseList
  def self.latest_release_for(repo)
    github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    release = github.releases(repo, per_page: 1).first
    release && release.tag_name
  end
end
