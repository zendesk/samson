require_relative '../test_helper'

describe Project do
  let(:project) { projects(:test) }
  let(:contents) { parse_role_config_file('kubernetes_role_config_file') }

  describe '#file_from_repo' do
    before do
      Rails.cache.clear
      Octokit::Client.any_instance.stubs(:contents).returns({ content: Base64.encode64(contents) })
    end

    it 'returns the decode file contents' do
      file_contents = project.file_from_repo('some_folder/other_file_name.rb', 'some_ref')
      assert_equal contents, file_contents
    end
  end

  describe '#directory_contents_from_repo' do
    before do
      Rails.cache.clear
      Octokit::Client.any_instance.stubs(:contents).returns([
        OpenStruct.new(name: 'file_name.yml', path: 'some_folder/file_name.yml'),
        OpenStruct.new(name: 'other_file_name.rb', path: 'some_folder/other_file_name.rb')
      ])
    end

    it 'returns the relevant files from the API response' do
      files = project.directory_contents_from_repo('some_folder', 'some_ref')
      assert_includes files, 'some_folder/file_name.yml'
      refute_includes files, 'some_folder/other_file_name.rb'
      assert_equal 1, files.size
    end
  end

  describe '#refresh_kubernetes_roles' do
    before do
      Project.any_instance.stubs(:directory_contents_from_repo).returns(['some_folder/file_name.yml'])
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

      project.reload.roles.each { |role|
        role.deleted?.must_equal false
      }

      project.roles.count.must_equal 1

      Kubernetes::Role.with_deleted do |scope|
        scope.where(project: project).count.must_equal original + 1
        scope.where(project: project).select(&:deleted?).count.must_equal original
      end
    end
  end
end



