require_relative '../test_helper'

describe Build do
  let(:project) { projects(:test) }

  describe 'validations' do
    it 'should validate git sha' do
      assert_valid(Build.new(project: project, git_sha: '0fbc33a0bfe9dcb5a17e26b9c319cce9d86ede14'))
      refute_valid(Build.new(project: project, git_sha: 'This is a string of 40 characters.......'))
      refute_valid(Build.new(project: project, git_sha: 'abc'))
    end

    it 'should validate container sha' do
      assert_valid(Build.new(project: project, container_sha: '0fbc33a0bfe9dcb5a17e26b9c319cce9d86ede14'))
      refute_valid(Build.new(project: project, container_sha: 'This is a string of 40 characters.......'))
      refute_valid(Build.new(project: project, container_sha: 'abc'))
    end
  end

  describe 'successful?' do
    let(:build) { builds(:staging) }

    it 'returns true when all successful' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::SUCCESSFUL)
      assert build.successful?
    end

    it 'returns false when there is a failure' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::FAILED)
      refute build.successful?
    end

    it 'returns false when there is a pending status' do
      build.statuses.create!(source: 'Jenkins', status: BuildStatus::SUCCESSFUL)
      build.statuses.create!(source: 'Travis',  status: BuildStatus::PENDING)
      refute build.successful?
    end
  end
end
