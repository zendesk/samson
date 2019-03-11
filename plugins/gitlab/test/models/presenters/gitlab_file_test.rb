# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Presenters::GitlabFile do
  let(:added_file) do
    {
      new_path: 'added_file',
      new_file: true,
      diff: "@@ -0,0 +1,2 @@\n+module Bar\n+end\n"
    }.stringify_keys
  end
  let(:modified_file) do
    {
      new_path: 'modified_file',
      diff: "@@ -1,4 +1,4 @@\n-module Bar\n+module Foo\n"
    }.stringify_keys
  end
  let(:deleted_file) do
    {
      new_path: 'deleted_file',
      deleted_file: true
    }.stringify_keys
  end

  describe "#build" do
    it "builds a new added file" do
      file = Presenters::GitlabFile.new(added_file).build
      file.filename.must_equal 'added_file'
      file.status.must_equal Presenters::GitlabFile::ADDED
      file.additions.must_equal 2
      file.deletions.must_equal 0
    end

    it "builds a new modified file" do
      file = Presenters::GitlabFile.new(modified_file).build
      file.filename.must_equal 'modified_file'
      file.status.must_equal Presenters::GitlabFile::MODIFIED
      file.additions.must_equal 1
      file.deletions.must_equal 1
    end

    it "builds a new deleted file" do
      file = Presenters::GitlabFile.new(deleted_file).build
      file.filename.must_equal 'deleted_file'
      file.status.must_equal Presenters::GitlabFile::REMOVED
      file.additions.must_equal 0
      file.deletions.must_equal 0
    end
  end
end
