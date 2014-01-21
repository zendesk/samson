require 'octokit'

class ReleaseList
  def self.latest_releases_for(repo)
    github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    github.releases(repo, limit: 30).map {|release| release.tag_name }
  end
end
