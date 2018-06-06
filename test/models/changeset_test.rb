# frozen_string_literal: true
require_relative '../test_helper'
require 'pry'
def maxitest_timeout;false;end

SingleCov.covered!

describe Changeset do

  describe "Github" do
    let(:changeset) { Changeset.new("foo/bar", "a", "b") }

    describe "#comparison" do
      it "builds a new changeset" do
        stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
        changeset.comparison.to_h.must_equal x: "y"
      end

      it "creates no comparison when the changeset is empty" do
        changeset = Changeset.new("foo/bar", "a", "a")
        changeset.comparison.class.must_equal Changeset::NullComparison
      end

      describe "with a specificed SHA" do
        it "caches" do
          request = stub_github_api("repos/foo/bar/compare/a...b", "x" => "y")
          2.times { Changeset.new("foo/bar", "a", "b").comparison.to_h.must_equal x: "y" }
          assert_requested request
        end
      end

      describe "with master" do
        it "doesn't cache" do
          stub_github_api("repos/foo/bar/branches/master", commit: { sha: "foo"})
          stub_github_api("repos/foo/bar/compare/a...foo", "x" => "y")
          Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "y"

          stub_github_api("repos/foo/bar/branches/master", commit: { sha: "bar"})
          stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
          Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
        end
      end

      {
        Octokit::NotFound => "GitHub: Not found",
        Octokit::Unauthorized => "GitHub: Unauthorized",
        Octokit::InternalServerError => "GitHub: Internal server error",
        Octokit::RepositoryUnavailable => "GitHub: Repository unavailable", # used to signal redirects too
        Faraday::ConnectionFailed.new("Oh no") => "GitHub: Oh no"
      }.each do |exception, message|
        it "catches #{exception} exceptions" do
          GITHUB.expects(:compare).raises(exception)
          comparison = Changeset.new("foo/bar", "a", "b").comparison
          comparison.error.must_equal message
        end
      end

      # tests config/initializers/octokit.rb Octokit::RedirectAsError
      it "converts a redirect into a NullComparison" do
        stub_github_api("repos/foo/bar/branches/master", {}, 301)
        Changeset.new("foo/bar", "a", "master").comparison.class.must_equal Changeset::NullComparison
      end

      # tests config/initializers/octokit.rb Octokit::RedirectAsError
      it "uses the cached body of a 304" do
        stub_github_api("repos/foo/bar/branches/master", {commit: { sha: "bar"}}, 304)
        Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
      end
    end

    describe "#vcs_url" do
      it "returns a URL to a GitHub comparison page" do
        changeset.vcs_url.must_equal "https://github.com/foo/bar/compare/a...b"
      end
    end

    describe "#files" do
      it "returns compared files" do
        stub_github_api("repos/foo/bar/compare/a...b", files: ["foo", "bar"])
        changeset.files.must_equal ["foo", "bar"]
      end
    end

    describe "#pull_requests" do
      let(:sawyer_agent) { Sawyer::Agent.new('') }
      let(:commit1) { Sawyer::Resource.new(sawyer_agent, commit: message1) }
      let(:commit2) { Sawyer::Resource.new(sawyer_agent, commit: message2) }
      let(:message1) { Sawyer::Resource.new(sawyer_agent, message: 'Merge pull request #42') }
      let(:message2) { Sawyer::Resource.new(sawyer_agent, message: 'Fix typo') }

      it "finds pull requests mentioned in merge commits" do
        comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1, commit2])
        GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

        Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns("yeah!")

        changeset.pull_requests.must_equal ["yeah!"]
      end

      it "ignores invalid pull request numbers" do
        comparison = Sawyer::Resource.new(sawyer_agent, commits: [commit1])
        GITHUB.stubs(:compare).with("foo/bar", "a", "b").returns(comparison)

        Changeset::PullRequest.stubs(:find).with("foo/bar", 42).returns(nil)

        changeset.pull_requests.must_equal []
      end
    end

    describe "#risks?" do
      it "is risky when there are risky requests" do
        changeset.expects(:pull_requests).returns([stub("commit", risky?: true)])
        changeset.risks?.must_equal true
      end

      it "is not risky when there are no risky requests" do
        changeset.expects(:pull_requests).returns([stub("commit", risky?: false)])
        changeset.risks?.must_equal false
      end
    end

    describe "#jira_issues" do
      it "returns a list of jira issues" do
        changeset.expects(:pull_requests).returns([stub("commit", jira_issues: [1, 2])])
        changeset.jira_issues.must_equal [1, 2]
      end
    end

    describe "#authors" do
      it "returns a list of authors" do
        changeset.expects(:commits).returns(
          [
            stub("c1", author: "foo"),
            stub("c2", author: "foo"),
            stub("c3", author: "bar")
          ]
        )
        changeset.authors.must_equal ["foo", "bar"]
      end
    end

    describe "#author_names" do
      it "returns a list of author's names" do
        changeset.expects(:commits).returns(
          [
            stub("c1", author_name: "foo"),
            stub("c2", author_name: "foo"),
            stub("c3", author_name: "bar")
          ]
        )
        changeset.author_names.must_equal ["foo", "bar"]
      end
    end

    describe "#error" do
      it "returns error" do
        stub_github_api("repos/foo/bar/compare/a...b", error: "foo")
        changeset.error.must_equal "foo"
      end
    end

    describe Changeset::NullComparison do
      it "has no commits" do
        Changeset::NullComparison.new(nil).commits.must_equal []
      end

      it "has no files" do
        Changeset::NullComparison.new(nil).files.must_equal []
      end
    end
  end

  describe "Gitlab" do
    before(:each) do
      GITLAB.private_token = auth[:token]
      stub_gitlab_api(projects_api_url, auth[:header], projects) # required for Changeset#project_id to be set.
    end

    let(:changeset) { Changeset.new('jane/repo', "a", "b", false) }
    let(:projects) { [{id: 1, path_with_namespace: "jane/repo"}] }
    let(:projects_api_url) { '/projects?per_page=20' }
    let(:project_compare_api_url) { "/projects/#{projects.first[:id]}/repository/compare?from=%s&to=%s" }
    let(:branch_url) { "/projects/#{projects.first[:id]}/repository/branches/%s" }
    let(:auth) { { header: {'Private-Token': 'phony-token'}, token: 'phony-token' } }
    let(:commit_b) {
      {id: "b", title: "b title", message: "b message",
       author_name: "Jesse Goerz", author_email: "jesse.goerz@plansource.com",
      }
    }
    let(:comparison_payload) { {
      commit: commit_b,
      commits: [
        commit_b,
        { id: "a", title: "a title", message: "a message",
          author_name: "Jesse Goerz", author_email: "jesse.goerz@plansource.com",
        }
      ],
      diffs: [
        {
          old_path: "a/foo",
          new_path: "a/foo",
          new_file: false,
          renamed_file: false,
          deleted_file: false,
          diff: "--- a/foo\n" +
            "+++ b/foo\n" +
            "@@ -9,7 +9,8 @@\n" +
            "module Module\n" +
            "\n" +
            "\n" +
            "- this is a deletion\n" +
            "- this is another deletion\n" +
            "+ this is an addition\n" +
            "+ this is an addition\n" +
            "+ this is an addition\n" +
            "\n"
        }
      ],
      compare_timeout: false,
      compare_same_ref: false
    }.with_indifferent_access }
    let(:branch_payload) { 
      {"name": "master",
        "commit": {
          "id": "a",
          "short_id": "a",
          "title": "the title",
          "created_at": "2018-04-11T22:20:58.000-06:00",
          "parent_ids": ["1234567", "89102345"],
          "message": " Do some stuff\n",
          "author_name": "Jesse Goerz",
          "author_email": "jgoerz@plansource.com",
          "authored_date": "2018-04-11T22:20:58.000-06:00",
          "committer_name": "Jesse Goerz",
          "committer_email": "jgoerz@plansource.com",
          "committed_date": "2018-04-11T22:20:58.000-06:00"
        },
        "merged": false,
        "protected": true,
        "developers_can_push": false,
        "developers_can_merge": false
      }
    }

    describe "#files" do
      it "returns compared files" do
        stub_gitlab_api(project_compare_api_url % ['a', 'b'], auth[:header], comparison_payload)
        changeset.files.must_equal Changeset::Files.new(comparison_payload['diffs'], false)
      end
    end

    describe "#project_id" do
      it "should grab the project id if it hasn't already been set xxx" do
        stub_gitlab_api(branch_url % 'master', auth[:header]) 
        c = Changeset.new('jane/repo', "a", "master", false)
        assert_equal(projects.first[:id], c.send(:project_id))
      end
    end

    describe "#comparison" do
      it "builds a new changeset" do
        stub_gitlab_api(project_compare_api_url % ['a', 'b'], auth[:header], comparison_payload)
        changeset.comparison.to_h.must_equal comparison_payload
      end

      it "creates no comparison when the changeset is empty" do
        changeset = Changeset.new(1, "a", "a", false)
        changeset.comparison.class.must_equal Changeset::NullComparison
      end

      it "converts a redirect into a NullComparison xxx" do
        stub_gitlab_api(branch_url % 'master', auth[:header], {}, 301) 
        Changeset.new("jane/repo", "a", "master", false).comparison.class.must_equal Changeset::NullComparison
      end

      # TODO equivalence testing for gitlab?
      # tests config/initializers/octokit.rb Octokit::RedirectAsError
      # it "uses the cached body of a 304" do
      #   stub_github_api("repos/foo/bar/branches/master", {commit: { sha: "bar"}}, 304)
      #   stub_github_api("repos/foo/bar/compare/a...bar", "x" => "z")
      #   Changeset.new("foo/bar", "a", "master").comparison.to_h.must_equal x: "z"
      # end
    end

    it "does not include nil authors" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author: "foo"),
          stub("c2", author: "bar"),
          stub("c3", author: nil)
        ]
      )
      changeset.authors.must_equal ["foo", "bar"]
    end
  end

    describe "#vcs_url" do
      it "returns a URL to a GitHub comparison page" do
        changeset.vcs_url.must_equal "https://gitlab.com/jane/repo/compare/a...b"
      end
    end

    it "doesnot include nil author names" do
      changeset.expects(:commits).returns(
        [
          stub("c1", author_name: "foo"),
          stub("c2", author_name: "bar"),
          stub("c3", author_name: nil)
        ]
      )
      changeset.author_names.must_equal ["foo", "bar"]
    end
  end

    describe "#authors" do
      it "returns a list of authors" do
        changeset.expects(:commits).returns(
          [
            stub("c1", author: "foo"),
            stub("c2", author: "foo"),
            stub("c3", author: "bar")
          ]
        )
        changeset.authors.must_equal ["foo", "bar"]
      end
    end

    describe "#author_names" do
      it "returns a list of author's names" do
        changeset.expects(:commits).returns(
          [
            stub("c1", author_name: "foo"),
            stub("c2", author_name: "foo"),
            stub("c3", author_name: "bar")
          ]
        )
        changeset.author_names.must_equal ["foo", "bar"]
      end
    end

    # describe "#error" do
    #   it "returns error" do
    #     stub_gitlab_api("repos/foo/bar/compare/a...b", error: "foo")
    #     changeset.error.must_equal "foo"
    #   end
    # end

    describe Changeset::NullComparison do
      it "has no commits" do
        Changeset::NullComparison.new(nil).commits.must_equal []
      end

      it "has no files" do
        Changeset::NullComparison.new(nil).files.must_equal []
      end
    end
  end
end
