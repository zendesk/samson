require_relative '../test_helper'

describe FlowdockNotificationRenderer do
  it "renders a nicely formatted notification" do
    changeset = stub("changeset")
    deploy = stub("deploy", short_reference: "xyz", changeset: changeset, url: 'test_url')

    author1 = "author1"
    author2 = "author2"
    changeset.stubs(:author_names).returns([author1, author2])

    commit1 = stub("commit1", url: "#", author_name: "author1", summary: "Introduce bug")
    commit2 = stub("commit2", url: "#", author_name: "author2", summary: "Fix bug")
    changeset.stubs(:commits).returns([commit1, commit2])

    file1 = stub("file1", status: "added", filename: "foo.rb")
    file2 = stub("file2", status: "modified", filename: "bar.rb")
    changeset.stubs(:files).returns([file1, file2])

    result = FlowdockNotificationRenderer.render(deploy)

    result.must_equal <<-RESULT.strip_heredoc.chomp
      <p>2 commits by author1 and author2.</p>

      <p><strong>Files changed</strong></p>
      <ul>
          <li><strong>A</strong> foo.rb</li>
          <li><strong>M</strong> bar.rb</li>
      </ul>

      <p><strong>Commits</strong></p>
      <ul>
          <li><a href="#">Introduce bug</a> (author1)</li>
          <li><a href="#">Fix bug</a> (author2)</li>
      </ul>
    RESULT
  end
end
