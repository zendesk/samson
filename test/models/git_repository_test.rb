# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: (ENV["CI"] ? 2 : 0)

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
    repository.send(:repository_url).must_equal project.repository_url
    repository.send(:repository_directory).must_equal project.repository_directory
  end

  describe "#ensure_mirror_current" do
    def call
      repository.send(:ensure_mirror_current)
    end

    it 'updates an existing repository' do
      create_repo_with_tags
      assert repository.send(:clone!)
      Dir.chdir(repository.repo_cache_dir) { number_of_commits }.must_equal 1

      # create an extra commit in the remote
      execute_on_remote_repo <<~SHELL
        echo monkey > foo2
        git add foo2
        git commit -m "second commit"
      SHELL

      # update mirror
      assert call

      # commit should now be locally available
      Dir.chdir(repository.repo_cache_dir) { number_of_commits }.must_equal 2

      # caches true
      repository.expects(:update!).never
      assert call
    end

    it 'clones when cache does not exist' do
      create_repo_without_tags
      refute File.exist?(repository.repo_cache_dir)

      assert call

      Dir.chdir(repository.repo_cache_dir) { number_of_commits }.must_equal 1
    end

    it 'returns false when update fails' do
      create_repo_with_tags
      assert repository.send(:clone!)
      assert system("rm -rf #{repository.repo_cache_dir}/*")

      refute call

      # caches false
      repository.expects(:update!).never
      refute call
    end

    it "is called from all public methods" do
      file = File.read("app/models/git_repository.rb")
      public = file.split(/^  private$/).first
      methods = public.scan(/^  def ([a-z_?!]+)(.*?)^  end/m)
      methods.size.must_be :>, 5 # making sure the logic is sound
      methods.delete_if { |method, _| ["update_mirror", "prune_worktree"].include?(method) }
      methods.each do |name, body|
        next if ["initialize", "repo_cache_dir", "clean!", "valid_url?"].include?(name)
        body.must_include "ensure_mirror_current", "Expected #{name} to update the repo with ensure_mirror_current"
      end
    end
  end

  describe "#commit_from_ref" do
    it 'returns the full commit id' do
      create_repo_with_tags
      repository.commit_from_ref('master').must_match /^[0-9a-f]{40}$/
    end

    it 'returns the full commit id when given a short commit id' do
      create_repo_with_tags
      short_commit_id = (execute_on_remote_repo "git rev-parse --short HEAD").strip
      repository.commit_from_ref(short_commit_id).must_match /^[0-9a-f]{40}$/
    end

    it 'returns nil if ref does not exist' do
      create_repo_with_tags
      repository.commit_from_ref('NOT A VALID REF').must_be_nil
    end

    it 'returns the commit of a branch' do
      create_repo_with_an_additional_branch('my_branch')
      repository.commit_from_ref('my_branch').must_match /^[0-9a-f]{40}$/
    end

    it 'returns the commit of a named tag' do
      create_repo_with_an_additional_branch('test_branch')
      execute_on_remote_repo <<~SHELL
        git checkout test_branch
        echo "blah blah" >> bar.txt
        git add bar.txt
        git commit -m "created bar.txt"
        git tag -a annotated_tag -m "This is really worth tagging"
        git checkout master
      SHELL

      sha = repository.commit_from_ref('annotated_tag')
      sha.must_match /^[0-9a-f]{40}$/
      repository.commit_from_ref('test_branch').must_equal(sha)
    end

    it 'prevents script insertion attacks' do
      create_repo_without_tags
      file = File.join(repo_temp_dir, "foo")
      assert File.exist?(file)
      repository.commit_from_ref("master ; rm #{file}").must_be_nil
      assert File.exist?(file)
    end

    it 'fails when mirror could not be updated' do
      repository.commit_from_ref('master').must_be_nil
    end
  end

  describe "#fuzzy_tag_from_ref" do
    it 'returns nil when repo has no tags' do
      create_repo_without_tags
      repository.fuzzy_tag_from_ref('master').must_be_nil
    end

    it 'returns the closest matching tag' do
      create_repo_with_tags
      execute_on_remote_repo <<~SHELL
        echo update > foo
        git commit -a -m 'untagged commit'
      SHELL
      repository.fuzzy_tag_from_ref('master~').must_equal 'v1'
      repository.fuzzy_tag_from_ref('master').must_match /^v1-1-g[0-9a-f]{7}$/
    end

    it 'returns tag when it is ambiguous' do
      create_repo_with_tags
      execute_on_remote_repo <<~SHELL
        git checkout -b v1
      SHELL
      repository.fuzzy_tag_from_ref('v1').must_equal 'v1'
    end

    it 'fails when mirror could not be updated' do
      repository.fuzzy_tag_from_ref('master').must_be_nil
    end
  end

  describe "#tags" do
    it 'returns the tags repository' do
      create_repo_with_tags
      repository.tags.to_a.must_equal ["v1"]
    end

    it 'returns an empty set of tags' do
      create_repo_without_tags
      repository.tags.must_equal []
    end

    it 'fails when repo is not updateable' do
      create_repo_with_an_additional_branch
      repository.expects(:ensure_mirror_current).returns(false)
      repository.tags.to_a.must_equal []
    end

    it 'fails when execution fails' do
      create_repo_with_an_additional_branch
      repository.expects(:capture_stdout).returns(false)
      repository.tags.to_a.must_equal []
    end
  end

  describe "#branches" do
    it 'returns the branches of the repository' do
      create_repo_with_an_additional_branch
      repository.branches.to_a.must_equal ['master', 'test_user/test_branch']
    end

    it 'fails when repo is not updateable' do
      create_repo_with_an_additional_branch
      repository.expects(:ensure_mirror_current).returns(false)
      repository.branches.to_a.must_equal []
    end

    it 'fails when execution fails' do
      create_repo_with_an_additional_branch
      repository.expects(:capture_stdout).returns(false)
      repository.branches.to_a.must_equal []
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

  describe "#checkout_workspace" do
    before { create_repo_with_an_additional_branch }

    it "fails without reference" do
      Dir.mktmpdir do |temp_dir|
        assert_raises(ArgumentError) { repository.checkout_workspace(temp_dir, '') }
      end
    end

    [true, false].each do |full_checkout|
      describe "with full_checkout #{full_checkout}" do
        before { repository.full_checkout = full_checkout }

        it 'creates a repository' do
          Dir.mktmpdir do |temp_dir|
            assert repository.checkout_workspace(temp_dir, 'test_user/test_branch')
            Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
          end
        end

        it 'checks out submodules' do
          skip "Somehow broken on CI" if ENV["CI"]
          add_submodule_to_repo
          Dir.mktmpdir do |temp_dir|
            assert repository.checkout_workspace(temp_dir, 'master')
            Dir.exist?("#{temp_dir}/submodule").must_equal true
            File.read("#{temp_dir}/submodule/bar").must_equal "banana\n"
          end
        end
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
    before { create_repo_without_tags }

    let!(:sha) { execute_on_remote_repo('git rev-parse master').strip }

    it 'finds content' do
      repository.file_content('foo', sha).must_equal "monkey"
    end

    it 'returns nil when file does not exist' do
      repository.file_content('foox', sha).must_be_nil
    end

    it 'returns nil when sha does not exist' do
      repository.file_content('foox', 'a' * 40).must_be_nil
    end

    it "complains about bad calls" do
      assert_raises ArgumentError do
        repository.file_content('foox', "")
      end.message.must_include "no reference"
    end

    describe "when checkout exists" do
      # create a checkout without marking "mirror_current?"
      before { Project.new(id: project.id, repository_url: repo_temp_dir).repository.send(:ensure_mirror_current) }

      it "updates for non-shas" do
        repository.expects(:ensure_mirror_current)
        repository.file_content('foox', 'a' * 41).must_be_nil
      end

      it "does not update when sha exists to save time" do
        repository.expects(:ensure_mirror_current).never
        repository.file_content('foo', sha).must_equal "monkey"
      end

      it "updates when sha is missing" do
        repository.expects(:ensure_mirror_current)
        repository.file_content('foo', 'a' * 40).must_be_nil
      end

      it "caches" do
        Samson::CommandExecutor.expects(:execute).times(2).returns([true, "x"])
        4.times { repository.file_content('foo', sha).must_equal "x" }
      end

      it "caches sha too" do
        Samson::CommandExecutor.expects(:execute).times(3).returns([true, "x"])
        4.times { |i| repository.file_content("foo-#{i.odd?}", sha).must_equal "x" }
      end

      it "does not pull when mirror is current" do
        repository.send(:ensure_mirror_current)
        repository.expects(:ensure_mirror_current).never
        repository.file_content('foo', 'a' * 40, pull: true).must_be_nil
      end

      describe "pull: false" do
        before { repository.expects(:ensure_mirror_current).never }

        it "finds known" do
          repository.file_content('foo', 'HEAD', pull: false).must_equal 'monkey'
        end

        it "ignores unknown" do
          repository.file_content('foo', 'aaaaaaaaa', pull: false).must_be_nil
        end

        it "ignores when repo does not exist" do
          FileUtils.rm_rf(repository.repo_cache_dir)
          repository.file_content('foo', 'HEAD', pull: false).must_be_nil
        end

        it "does not cache when requesting for an update" do
          repository.unstub(:ensure_mirror_current)
          repository.expects(:ensure_mirror_current)
          Samson::CommandExecutor.expects(:execute).times(2).returns([true, "x"])
          repository.file_content('foo', 'HEAD', pull: false).must_equal "x"
          4.times { repository.file_content('foo', 'HEAD', pull: true).must_equal "x" }
        end
      end
    end
  end

  describe '#exclusive' do
    let(:output) { StringIO.new }
    let(:lock_key) { repository.repo_cache_dir }

    after { MultiLock.locks.clear }

    it 'locks' do
      refute MultiLock.locks[lock_key]
      repository.send(:exclusive) do
        assert MultiLock.locks[lock_key]
      end
      refute MultiLock.locks[lock_key]
    end

    it "does not log waiting when not waiting" do
      repository.send(:exclusive) {}
      repository.executor.output.string.must_equal ""
    end

    describe "when already locked" do
      before do
        MultiLock.stubs(:sleep).with { sleep 0.1 } # make test sleep 0.1 instead of 1
        MultiLock.locks[lock_key] = true
      end

      it 'fails to execute' do
        time = Benchmark.realtime do
          repository.send(:exclusive, timeout: 0.1) { raise "NEVER" }
        end
        time.must_be :>, 0.1
        assert MultiLock.locks[lock_key] # still locked
      end

      it 'executes error callback if it cannot lock' do
        refute(repository.send(:exclusive, timeout: 0.1)) { raise "NEVER" }
        repository.executor.output.string.must_equal "Waiting for repository lock for true\n"
      end

      it 'logs once every 10 tries' do
        refute(repository.send(:exclusive, timeout: 1.1)) { raise "NEVER" }
        repository.executor.output.string.
          must_equal("Waiting for repository lock for true\nWaiting for repository lock for true\n")
      end
    end
  end

  describe "#outside_caller" do
    let(:callsite) { "git_repository_test.rb:#{__LINE__ + 3}:in `call'" }

    def call
      repository.send(:exclusive) { repository.send(:outside_caller) }
    end

    it "finds caller" do
      call.must_equal callsite
    end

    it "does not blow up on unknown caller" do
      repository.send(:outside_caller).must_equal "Unknown"
    end

    it "ignores monkey-patching" do
      MultiLock.expects(:lock).yields
      call.must_equal callsite
    end
  end

  describe "#prune_worktree" do
    it "silently prunes" do
      create_repo_without_tags
      Dir.mktmpdir do |dir|
        repository.checkout_workspace dir, 'master'
      end
      repository.prune_worktree
      `cd #{repository.repo_cache_dir} && git worktree list`.split("\n").size.must_equal 1
      repository.executor.output.string.wont_include "prune"
    end
  end

  describe "#instance_cache" do
    it "caches" do
      c = 0
      2.times { repository.send(:instance_cache, 1) { c += 1 }.must_equal c }
      c.must_equal 1
    end

    it "caches nils" do
      c = 0
      2.times { repository.send(:instance_cache, 1) { c += 1; nil }.must_be_nil }
      c.must_equal 1
    end
  end
end
