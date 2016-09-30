# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReferencesService do
  include GitRepoTestHelper

  let!(:repository_url) do
    create_repo_with_tags
    execute_on_remote_repo("git checkout -b test_user/test_branch")
  end

  let!(:project) { Project.create!(name: 'test_project', repository_url: repo_temp_dir) }

  before do
    project.repository.update_local_cache!
  end

  after do
    FileUtils.rm_rf(repo_temp_dir)
    project.repository.clean!
  end

  it 'returns a sorted set of tags and branches' do
    ReferencesService.new(project).find_git_references.must_equal %w[v1 master test_user/test_branch]
  end

  it 'returns a sorted set of tags and branches from cached repo' do
    ReferencesService.new(project).send(:references_from_cached_repo).must_equal %w[v1 master test_user/test_branch]
  end

  it 'the ttl threshold should always return an integer' do
    Rails.application.config.samson.stubs(:references_cache_ttl).returns('10')
    references_service = ReferencesService.new(project)
    references_service.send(:references_ttl).must_equal 10
  end
end
