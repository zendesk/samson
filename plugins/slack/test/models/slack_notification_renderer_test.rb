require_relative '../test_helper'

describe SlackNotificationRenderer do
  it "renders a nicely formatted notification" do
    changeset = stub("changeset")
    deploy = stub("deploy", short_reference: "xyz", changeset: changeset)

    author1 = "author1"
    author2 = "author2"
    changeset.stubs(:author_names).returns([author1, author2])

    commit1 = stub("commit1", url: "#", author_name: "author1", summary: "Introduce bug")
    commit2 = stub("commit2", url: "#", author_name: "author2", summary: "Fix bug")
    changeset.stubs(:commits).returns([commit1, commit2])

    file1 = stub("file1", status: "added", filename: "foo.rb")
    file2 = stub("file2", status: "modified", filename: "bar.rb")
    changeset.stubs(:files).returns([file1, file2])

    subject = "Deploy starting"

    result = SlackNotificationRenderer.render(deploy, subject)

    result.must_equal <<-RESULT.strip_heredoc.chomp
:point_right: *Deploy starting* :point_left:
_2 commits by author1 and author2._

*Files changed*

> A foo.rb
> M bar.rb

*Commits*

> <#|Introduce bug> (author1)
> <#|Fix bug> (author2)
    RESULT
  end
end
