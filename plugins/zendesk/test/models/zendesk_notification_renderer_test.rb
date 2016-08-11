# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe ZendeskNotificationRenderer do
  it "renders a nicely formatted notification" do
    changeset = stub("changeset")
    project = stub(name: "Project")
    stage = stub(name: "Production")
    deploy = stub(short_reference: "v2.14", project: project, changeset: changeset, stage: stage)
    ticket_id = 18

    ZendeskNotificationRenderer.stubs(:url).returns("http://example.org/deploys/20")

    author1 = "author1"
    author2 = "author2"
    changeset.stubs(:authors).returns([author1, author2])

    commit1 = stub("commit1", url: "#", author_name: "author1", summary: "ZD#18 this fixes a very bad bug")
    commit2 = stub("commit2", url: "#", author_name: "author2", summary: "Merge pull request #19 from example/ZD18")
    changeset.stubs(:commits).returns([commit1, commit2])

    result = ZendeskNotificationRenderer.render(deploy, ticket_id)

    result.must_equal <<-RESULT.strip_heredoc.chomp
      A fix to Project for this issue has been deployed to Production. Deploy details: [v2.14] (http://example.org/deploys/20)

      **Related Commits:**

        * [ZD#18 this fixes a very bad bug] (#) (author1)
        * [Merge pull request #19 from example/ZD18] (#) (author2)

    RESULT
  end
end
