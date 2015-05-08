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
end
