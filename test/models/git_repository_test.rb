# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GitRepository do
  include GitRepoTestHelper

  let(:project) { Project.new(id: 99999, name: 'test_project', repository_url: repo_temp_dir) }
  let(:repository) { project.repository }
  let(:repo_dir) { File.join(GitRepository.cached_repos_dir, project.repository_directory) }

  after do
    FileUtils.rm_rf(repo_temp_dir)
    FileUtils.rm_rf(repo_dir)
    repository.clean!
  end

  it 'checks that the project repository is pointing to the correct url and directory' do
    repository.is_a? GitRepository
    repository.repository_url.must_equal project.repository_url
    repository.repository_directory.must_equal project.repository_directory
  end

  describe "#create_workspace" do
    it 'clones a repository' do
      Dir.mktmpdir do |dir|
        create_repo_without_tags
        FileUtils.mv(repo_temp_dir, repository.repo_cache_dir)

        repository.send(:create_workspace, dir).must_equal true
        Dir.exist?("#{dir}/.git").must_equal true
      end
    end

    it "returns false when clone fails" do
      Dir.mktmpdir do |dir|
        repository.send(:create_workspace, dir).must_equal false
        Dir.exist?("#{dir}/.git").must_equal false
      end
    end
  end

  describe "#update_local_cache!" do
    it 'updates an existing repository' do
      create_repo_with_tags
      repository.send(:clone!).must_equal(true)
      Dir.chdir(repository.repo_cache_dir) do
        number_of_commits.must_equal 1
      end

      Dir.chdir(repository.repo_cache_dir) { number_of_commits.must_equal(1) }

      # create an extra commit in the remote
      execute_on_remote_repo <<-SHELL
        echo monkey > foo2
        git add foo2
        git commit -m "second commit"
      SHELL

      repository.update_local_cache!.must_equal(true)

      # commit should now be locally available
      Dir.chdir(repository.repo_cache_dir) do
        number_of_commits('master').must_equal(2)
      end
    end

    it 'clones when cache does not exist' do
      create_repo_without_tags
      File.exist?(repository.repo_cache_dir).must_equal false

      repository.update_local_cache!.must_equal(true)

      Dir.chdir(repository.repo_cache_dir) do
        number_of_commits.must_equal(1)
      end
    end

    it 'returns false when update fails' do
      create_repo_with_tags
      repository.send(:clone!).must_equal(true)
      assert system("rm -rf #{repository.repo_cache_dir}/*")
      repository.update_local_cache!.must_equal false
    end
  end

  describe "#checkout!" do
    it 'switches to a different branch' do
      create_repo_with_an_additional_branch
      repository.update_local_cache!
      repository.send(:checkout!, 'master', repo_temp_dir).must_equal(true)
      Dir.chdir(repo_temp_dir) { current_branch.must_equal('master') }
      repository.send(:checkout!, 'test_user/test_branch', repo_temp_dir).must_equal(true)
      Dir.chdir(repo_temp_dir) { current_branch.must_equal('test_user/test_branch') }
    end
  end

  describe "#commit_from_ref" do
    it 'returns the full commit id' do
      create_repo_with_tags
      repository.update_local_cache!
      repository.commit_from_ref('master').must_match /^[0-9a-f]{40}$/
    end

    it 'returns the full commit id when given a short commit id' do
      create_repo_with_tags
      repository.update_local_cache!
      short_commit_id = (execute_on_remote_repo "git rev-parse --short HEAD").strip
      repository.commit_from_ref(short_commit_id).must_match /^[0-9a-f]{40}$/
    end

    it 'returns nil if ref does not exist' do
      create_repo_with_tags
      repository.update_local_cache!
      repository.commit_from_ref('NOT A VALID REF').must_be_nil
    end

    it 'returns the commit of a branch' do
      create_repo_with_an_additional_branch('my_branch')
      repository.update_local_cache!
      repository.commit_from_ref('my_branch').must_match /^[0-9a-f]{40}$/
    end

    it 'returns the commit of a named tag' do
      create_repo_with_an_additional_branch('test_branch')
      execute_on_remote_repo <<-SHELL
        git checkout test_branch
        echo "blah blah" >> bar.txt
        git add bar.txt
        git commit -m "created bar.txt"
        git tag -a annotated_tag -m "This is really worth tagging"
        git checkout master
      SHELL

      repository.update_local_cache!
      sha = repository.commit_from_ref('annotated_tag')
      sha.must_match /^[0-9a-f]{40}$/
      repository.commit_from_ref('test_branch').must_equal(sha)
    end

    it 'prevents script insertion attacks' do
      create_repo_without_tags
      repository.update_local_cache!
      file = File.join(repo_temp_dir, "foo")
      assert File.exist?(file)
      repository.commit_from_ref("master ; rm #{file}").must_be_nil
      assert File.exist?(file)
    end
  end

  describe "#fuzzy_tag_from_ref" do
    it 'returns nil when repo has no tags' do
      create_repo_without_tags
      repository.update_local_cache!
      repository.fuzzy_tag_from_ref('master').must_be_nil
    end

    it 'returns the closest matching tag' do
      create_repo_with_tags
      execute_on_remote_repo <<-SHELL
        echo update > foo
        git commit -a -m 'untagged commit'
      SHELL
      repository.update_local_cache!
      repository.fuzzy_tag_from_ref('master~').must_equal 'v1'
      repository.fuzzy_tag_from_ref('master').must_match /^v1-1-g[0-9a-f]{7}$/
    end

    it 'returns tag when it is ambiguous' do
      create_repo_with_tags
      execute_on_remote_repo <<-SHELL
        git checkout -b v1
      SHELL
      repository.update_local_cache!
      repository.fuzzy_tag_from_ref('v1').must_equal 'v1'
    end
  end

  describe "#tags" do
    it 'returns the tags repository' do
      create_repo_with_tags
      repository.update_local_cache!
      repository.tags.to_a.must_equal ["v1"]
    end

    it 'returns an empty set of tags' do
      create_repo_without_tags
      repository.update_local_cache!
      repository.tags.must_equal []
    end
  end

  describe "#branches" do
    it 'returns the branches of the repository' do
      create_repo_with_an_additional_branch
      repository.update_local_cache!
      repository.branches.to_a.must_equal %w[master test_user/test_branch]
    end
  end

  describe "#valid_url?" do
    it 'validates the repo url' do
      create_repo_without_tags
      repository.valid_url?.must_equal true
    end

    it 'invalidates the repo url without repo' do
      repository.valid_url?.must_equal false
    end
  end

  describe ".checkout_workspace" do
    before { create_repo_with_an_additional_branch }

    it 'creates a repository' do
      Dir.mktmpdir do |temp_dir|
        assert repository.checkout_workspace(temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end

    it 'updates an existing repository to a branch' do
      Dir.mktmpdir do |temp_dir|
        repository.update_local_cache!
        assert repository.checkout_workspace(temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end

    it 'does not update cache when the cache was already updated' do
      Dir.mktmpdir do |temp_dir|
        # updates the cache
        repository.update_local_cache!

        # remote has changed
        execute_on_remote_repo <<-SHELL
          git checkout test_user/test_branch
          echo CHANGED > foo
          git commit -am more
          git checkout master
        SHELL

        # change is not visible
        assert repository.checkout_workspace(temp_dir, 'test_user/test_branch')
        File.read("#{temp_dir}/foo").must_equal "monkey\n"
      end
    end
  end

  describe '#checkout_submodules!' do
    before do
      create_repo_with_submodule
    end

    it 'checks out submodules' do
      Dir.mktmpdir do |temp_dir|
        assert repository.checkout_workspace(temp_dir, 'master')
        Dir.exist?("#{temp_dir}/submodule").must_equal true
        File.read("#{temp_dir}/submodule/bar").must_equal "banana\n"
      end
    end
  end

  describe "#clean!" do
    it 'removes a repository' do
      create_repo_without_tags
      Dir.mktmpdir do |temp_dir|
        assert repository.checkout_workspace(temp_dir, 'master')
        Dir.exist?(repository.repo_cache_dir).must_equal true
        repository.clean!
        Dir.exist?(repository.repo_cache_dir).must_equal false
      end
    end

    it 'does not fail when repo is missing' do
      repository.clean!
    end
  end

  describe "#file_content" do
    before do
      create_repo_without_tags
      repository.update_local_cache!
    end

    let(:sha) { repository.commit_from_ref('master') }

    it 'finds content' do
      repository.file_content('foo', sha).must_equal "monkey"
    end

    it 'returns nil when file does not exist' do
      repository.file_content('foox', sha).must_be_nil
    end

    it 'returns nil when sha does not exist' do
      repository.file_content('foox', 'a' * 40).must_be_nil
    end

    it "always updates for non-shas" do
      repository.expects(:sha_exist?).never
      repository.expects(:update!)
      repository.file_content('foox', 'a' * 41).must_be_nil
    end

    it "does not update when sha exists to save time" do
      repository.expects(:update!).never
      repository.file_content('foo', sha).must_equal "monkey"
    end

    it "updates when sha is missing" do
      repository.expects(:update!)
      repository.file_content('foo', 'a' * 40).must_be_nil
    end

    describe "pull: false" do
      before { repository.expects(:update!).never }

      it "finds known" do
        repository.file_content('foo', 'HEAD', pull: false).must_equal 'monkey'
      end

      it "ignores unknown" do
        repository.file_content('foo', 'aaaaaaaaa', pull: false).must_be_nil
      end
    end
  end

  describe '#exclusive' do
    let(:output) { StringIO.new }
    let(:lock_key) { repository.repo_cache_dir }

    after { MultiLock.locks.clear }

    it 'locks' do
      MultiLock.locks[lock_key].must_be_nil
      repository.exclusive(output: output, holder: 'test', timeout: 2.seconds) do
        MultiLock.locks[lock_key].wont_be_nil
      end
      MultiLock.locks[lock_key].must_be_nil
    end

    it 'fails to lock when already locked' do
      MultiLock.locks[lock_key] = true
      repository.exclusive(output: output, holder: 'test', timeout: 1.seconds) { output.puts("Can't get here") }
      MultiLock.locks[lock_key].wont_be_nil
      output.string.wont_include "Can't get here"
    end

    it 'executes error callback if it cannot lock' do
      MultiLock.locks[lock_key] = true
      refute repository.exclusive(output: output, holder: 'test', timeout: 1.seconds) do
        output.puts("Can't get here")
      end
      output.string.wont_include "Can't get here"
    end
  end
end
