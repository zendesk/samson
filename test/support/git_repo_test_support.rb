# frozen_string_literal: true
module GitRepoTestHelper
  def repo_temp_dir
    @repo_temp_dir ||= Dir.mktmpdir
  end

  def submodule_temp_dir
    @submodule_temp_dir ||= Dir.mktmpdir
  end

  def execute_on_remote_repo(cmds, repo_dir = repo_temp_dir)
    result = `exec 2>&1; set -e; cd #{repo_dir}; #{cmds}`
    raise "FAIL: #{result}" unless $?.success?
    result
  end

  def create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      #{init_repo_commands}
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
    SHELL
  end

  def create_repo_with_tags(tag_name = 'v1')
    create_repo_without_tags
    execute_on_remote_repo "git tag #{tag_name}"
  end

  def create_repo_with_an_additional_branch(branch_name = 'test_user/test_branch')
    create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      git checkout -b #{branch_name}
      echo monkey > foo2
      git add foo2
      git commit -m "branch commit"
      git checkout master
    SHELL
  end

  def create_repo_with_second_commit
    create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      echo more-monkey >> foo
      git add foo
      git commit -m "added more monkey"
    SHELL
  end

  def add_submodule_to_repo
    create_submodule_repo
    execute_on_remote_repo <<-SHELL
      git submodule add #{submodule_temp_dir} submodule
      git add .gitmodules
      git add submodule
      git commit -m "added submodule"
    SHELL
  end

  def create_submodule_repo
    commands = <<-SHELL
      #{init_repo_commands}
      echo banana > bar
      git add bar
      git commit -m "initial submodule commit"
    SHELL
    execute_on_remote_repo commands, submodule_temp_dir
  end

  def init_repo_commands
    <<-SHELL
      git init --initial-branch=master
      git config protocol.file.allow always
      git config user.email "test@example.com"
      git config user.name "Test User"
      git config commit.gpgsign false
    SHELL
  end

  def current_branch
    `git rev-parse --abbrev-ref HEAD`.strip
  end

  def current_commit
    `git rev-parse HEAD`.strip
  end

  def number_of_commits(ref = 'HEAD')
    `git rev-list #{ref} --count`.strip.to_i
  end

  def update_workspace
    `git pull`.strip
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def with_project_on_remote_repo
      around do |test|
        Dir.mktmpdir do |dir|
          @repo_temp_dir = dir
          create_repo_without_tags
          project.update_column(:repository_url, @repo_temp_dir)
          test.call
        end
      end
    end
  end
end
