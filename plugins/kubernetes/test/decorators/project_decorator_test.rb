require_relative '../test_helper'

SingleCov.covered! uncovered: 3

describe Project do
  include GitRepoTestHelper

  let(:project) { projects(:test) }
  let(:contents) { read_kubernetes_sample_file('kubernetes_role_config_file.yml') }

  describe '#file_from_repo' do
    it 'returns the file contents' do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
      project.file_from_repo('foo', 'HEAD').must_equal 'monkey'
    end
  end

  describe '#kubernetes_config_files_in_repo' do
    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
    end

    it 'returns config files' do
      execute_on_remote_repo <<-SHELL
        mkdir nope
        touch nope/config.yml
        touch kuernetes.yml

        mkdir kubernetes
        touch kubernetes/config.yml
        touch kubernetes/config.yaml
        touch kubernetes/config.json
        touch kubernetes/config.foo
        touch kubernetes/config.y2k

        git add .
        git commit -m "second commit"
      SHELL

      project.kubernetes_config_files_in_repo('HEAD').must_equal ["kubernetes/config.json", "kubernetes/config.yaml", "kubernetes/config.yml"]
    end

    it "returns empty array when nothing was found" do
      project.kubernetes_config_files_in_repo('HEAD').must_equal []
    end

    it "returns empty array on error" do
      project.kubernetes_config_files_in_repo('DSFFSDJKDFSHDSFHSFDHJ').must_equal []
    end
  end

  describe '#refresh_kubernetes_roles' do
    before do
      Project.any_instance.stubs(:kubernetes_config_files_in_repo).returns(['some_folder/file_name.yml'])
      Project.any_instance.stubs(:file_from_repo).returns(contents)
    end

    it 'returns the imported kubernetes roles' do
      roles = project.refresh_kubernetes_roles!('some_ref')
      expected = roles.first
      expected.id.wont_be_nil
      expected.name.must_equal 'some-role'
      expected.config_file.must_equal 'some_folder/file_name.yml'
      expected.service_name.must_equal 'some-project'
      expected.ram.must_equal 100
      expected.cpu.must_equal 0.5
      expected.replicas.must_equal 2
      expected.deploy_strategy.must_equal 'RollingUpdate'
    end

    it 'saves the imported roles into the database' do
      roles = project.refresh_kubernetes_roles!('some_ref')
      saved = roles.first

      Kubernetes::Role.find(saved.id).wont_be_nil
    end

    it 'soft deletes the previously existing roles' do
      original = project.roles.count

      project.roles.each { |role|
        role.deleted?.must_equal false
      }

      project.refresh_kubernetes_roles!('some_ref')

      project.reload.roles.not_deleted.each { |role|
        role.deleted?.must_equal false
      }

      project.roles.not_deleted.count.must_equal 1

      Kubernetes::Role.with_deleted do |scope|
        scope.where(project: project).count.must_equal original + 1
        scope.where(project: project).select(&:deleted?).count.must_equal original
      end
    end
  end
end



