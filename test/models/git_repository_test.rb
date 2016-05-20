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

  describe "#clone!" do
    it 'clones a repository' do
      Dir.mktmpdir do |dir|
        create_repo_with_tags
        repository.clone!(from: repo_temp_dir, to: dir).must_equal true
        Dir.exist?("#{dir}/.git").must_equal true
      end
    end

    it "returns false when clone fails" do
      Dir.mktmpdir do |dir|
        repository.clone!(from: repo_temp_dir, to: dir).must_equal false
        Dir.exist?("#{dir}/.git").must_equal false
      end
    end
  end

  describe "#update_local_cache!" do
    it 'updates an existing repository' do
      create_repo_with_tags
      repository.clone!.must_equal(true)
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
        number_of_commits('origin/master').must_equal(2)
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
      repository.clone!.must_equal(true)
      Dir.chdir(repository.repo_cache_dir) do
        raise unless system("git remote rm origin")
      end
      repository.update_local_cache!.must_equal false
    end
  end

  describe "#cheakout!" do
    it 'switches to a different branch' do
      create_repo_with_an_additional_branch
      repository.clone!.must_equal(true)
      repository.send(:checkout!, 'master').must_equal(true)
      Dir.chdir(repository.repo_cache_dir) { current_branch.must_equal('master') }
      repository.send(:checkout!, 'test_user/test_branch').must_equal(true)
      Dir.chdir(repository.repo_cache_dir) { current_branch.must_equal('test_user/test_branch') }
    end
  end

  describe "#commit_from_ref" do
    it 'returns the short commit id' do
      create_repo_with_tags
      repository.clone!
      repository.commit_from_ref('master').must_match /^[0-9a-f]{7}$/
    end

    it 'returns the full commit id with nil length' do
      create_repo_with_tags
      repository.clone!
      repository.commit_from_ref('master', length: nil).must_match /^[0-9a-f]{40}$/
    end

    it 'returns nil if ref does not exist' do
      create_repo_with_tags
      repository.clone!
      repository.commit_from_ref('NOT A VALID REF', length: nil).must_be_nil
    end

    it 'returns the commit of a branch' do
      create_repo_with_an_additional_branch('my_branch')
      repository.clone!(mirror: true)
      repository.commit_from_ref('my_branch').must_match /^[0-9a-f]{7}$/
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

      repository.clone!(mirror: true)
      sha = repository.commit_from_ref('annotated_tag', length: 40)
      sha.must_match /^[0-9a-f]{40}$/
      repository.commit_from_ref('test_branch', length: 40).must_equal(sha)
    end

    it 'prevents script insertion attacks' do
      create_repo_without_tags
      repository.clone!
      repository.commit_from_ref('master ; rm foo', length: nil).must_be_nil
      assert File.exist?(File.join(repository.repo_cache_dir, 'foo'))
    end
  end

  describe "#tag_from_ref" do
    it 'returns nil when repo has no tags' do
      create_repo_without_tags
      repository.clone!
      repository.tag_from_ref('master').must_be_nil
    end

    it 'returns the closest matching tag' do
      create_repo_with_tags
      execute_on_remote_repo <<-SHELL
        echo update > foo
        git commit -a -m 'untagged commit'
      SHELL
      repository.clone!
      repository.tag_from_ref('master~').must_equal 'v1'
      repository.tag_from_ref('master').must_match /^v1-1-g[0-9a-f]{7}$/
    end
  end

  describe "#tags" do
    it 'returns the tags repository' do
      create_repo_with_tags
      repository.clone!(mirror: true)
      repository.tags.to_a.must_equal ["v1"]
    end

    it 'returns an empty set of tags' do
      create_repo_without_tags
      repository.clone!(mirror: true)
      repository.tags.must_equal []
    end
  end

  describe "#branches" do
    it 'returns the branches of the repository' do
      create_repo_with_an_additional_branch
      repository.clone!(mirror: true)
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

  describe "#setup!" do
    it 'creates a repository' do
      create_repo_with_an_additional_branch
      Dir.mktmpdir do |temp_dir|
        assert repository.setup!(temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end

    it 'updates an existing repository to a branch' do
      create_repo_with_an_additional_branch
      Dir.mktmpdir do |temp_dir|
        repository.send(:clone!, mirror: true)
        assert repository.setup!(temp_dir, 'test_user/test_branch')
        Dir.chdir(temp_dir) { current_branch.must_equal('test_user/test_branch') }
      end
    end
  end

  describe "#clean!" do
    it 'removes a repository' do
      create_repo_without_tags
      Dir.mktmpdir do |temp_dir|
        assert repository.setup!(temp_dir, 'master')
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
      repository.clone!
    end

    let(:sha) { repository.commit_from_ref('master', length: nil) }

    it 'finds content' do
      repository.file_content('foo', sha).must_equal "monkey"
    end

    it 'returns nil when file does not exist' do
      repository.file_content('foox', sha).must_equal nil
    end

    it 'returns nil when sha does not exist' do
      repository.file_content('foox', 'a' * 40).must_equal nil
    end

    it "always updates for non-shas" do
      repository.expects(:sha_exist?).never
      repository.expects(:update!)
      repository.file_content('foox', 'a' * 41).must_equal nil
    end

    it "does not update when sha exists to save time" do
      repository.expects(:update!).never
      repository.file_content('foo', sha).must_equal "monkey"
    end

    it "updates when sha is missing" do
      repository.expects(:update!)
      repository.file_content('foo', 'a' * 40).must_equal nil
    end
  end
end
