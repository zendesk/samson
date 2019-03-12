# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Gitlab::ChangesetPresenter do
  let(:data) do
    OpenStruct.new(
      diffs: [{new_path: 'test_file'}.stringify_keys],
      commits: [{message: 'Initial commit'}.stringify_keys]
    )
  end

  describe "#build" do
    it "builds a new changeset" do
      changeset = Gitlab::ChangesetPresenter.new(data).build
      changeset.files.size.must_equal 1
      changeset.files.first.filename.must_equal 'test_file'
      changeset.commits.size.must_equal 1
      changeset.commits.first.commit.message.must_equal 'Initial commit'
    end
  end
end
