module GitRepoTestHelper
  def repo_temp_dir
    @repo_temp_dir ||= Dir.mktmpdir
  end

  def execute_on_remote_repo(cmds)
    result = `exec 2>&1; set -e; cd #{repo_temp_dir}; #{cmds}`
    raise "FAIL: #{result}" unless $?.success?
    result
  end

  def create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      git init
      git config user.email "test@example.com"
      git config user.name "Test User"
      git config commit.gpgsign false
      echo monkey > foo
      git add foo
      git commit -m "initial commit"
    SHELL
  end

  def create_repo_with_tags(tag_name = 'v1')
    create_repo_without_tags
    execute_on_remote_repo <<-SHELL
      git tag #{tag_name}
    SHELL
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
end
