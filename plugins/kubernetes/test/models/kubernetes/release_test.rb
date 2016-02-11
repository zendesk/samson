require_relative '../../test_helper'

describe Kubernetes::Release do
  let(:build)  { builds(:docker_build) }
  let(:user)   { users(:deployer) }
  let(:release) { Kubernetes::Release.new(build: build, user: user) }
  let(:deploy_group) { deploy_groups(:pod1) }
  let(:project) { projects(:test) }
  let(:app_server) { kubernetes_roles(:app_server) }
  let(:resque_worker) { kubernetes_roles(:resque_worker) }
  let(:role_config_file) { parse_role_config_file('kubernetes_role_config_file') }

  describe 'validations' do
    it 'asserts image is in registry' do
      release.build = builds(:staging)    # does not have a docker image pushed
      refute_valid(release, :build)
    end
  end

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(release)
    end

    it 'test validity of status' do
      Kubernetes::Release::STATUSES.each do |status|
        assert_valid(release.tap { |kr| kr.status = status })
      end
      refute_valid(release.tap { |kr| kr.status = 'foo' })
      refute_valid(release.tap { |kr| kr.status = nil })
    end
  end

  describe '#create_release' do

    describe 'with one single role' do
      setup :expect_file_contents_from_repo
      setup :current_release_count

      it 'creates the Release and all the corresponding ReleaseDocs' do
        release = Kubernetes::Release.create_release(release_params)
        release.build.id.must_equal release_params[:build_id]
        release.release_docs.count.must_equal 1
        release.release_docs.first.kubernetes_role.id.must_equal app_server.id
        release.release_docs.first.kubernetes_role.name.must_equal app_server.name
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'with multiple roles' do
      setup { 2.times { expect_file_contents_from_repo } }
      setup :current_release_count

      it 'creates the Release and all the corresponding ReleaseDocs' do
        release = Kubernetes::Release.create_release(multiple_roles_release_params)
        release.build.id.must_equal release_params[:build_id]
        release.release_docs.count.must_equal 2
        release.release_docs.first.kubernetes_role.id.must_equal app_server.id
        release.release_docs.first.kubernetes_role.name.must_equal app_server.name
        release.release_docs.first.kubernetes_role.replicas.must_equal app_server.replicas
        release.release_docs.first.kubernetes_role.cpu.must_equal app_server.cpu
        release.release_docs.first.kubernetes_role.ram.must_equal app_server.ram
        release.release_docs.second.kubernetes_role.id.must_equal resque_worker.id
        release.release_docs.second.kubernetes_role.name.must_equal resque_worker.name
        release.release_docs.second.kubernetes_role.replicas.must_equal resque_worker.replicas
        release.release_docs.second.kubernetes_role.cpu.must_equal resque_worker.cpu
        release.release_docs.second.kubernetes_role.ram.must_equal resque_worker.ram
        assert_release_count(@current_release_count + 1)
      end
    end

    describe 'with missing deploy groups' do
      setup :current_release_count

      it_should_raise_an_exception do
        Kubernetes::Release.create_release(release_params.except(:deploy_groups)) #nil
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        Kubernetes::Release.create_release(release_params.tap { |params| params[:deploy_groups].clear }) #empty
        assert_release_count(@current_release_count)
      end
    end

    describe 'with missing roles' do
      setup :current_release_count

      it_should_raise_an_exception do
        Kubernetes::Release.create_release(release_params.tap { |params| params[:deploy_groups].each { |dg| dg.delete(:roles) } }) #nil
        assert_release_count(@current_release_count)
      end

      it_should_raise_an_exception do
        Kubernetes::Release.create_release(release_params.tap { |params| params[:deploy_groups].each { |dg| dg[:roles].clear } }) #empty
        assert_release_count(@current_release_count)
      end
    end
  end

  def expect_file_contents_from_repo
    Build.any_instance.expects(:file_from_repo).returns(role_config_file)
  end

  def current_release_count
    @current_release_count = project.kubernetes_releases.count
  end

  def release_params
    {
      build_id: build.id,
      deploy_groups: [
        {
          id: deploy_group.id,
          roles: [
            {
              id: app_server.id,
              replicas: app_server.replicas
            }
          ]
        }
      ]
    }
  end

  def multiple_roles_release_params
    release_params.tap do |params|
      params[:deploy_groups].each do |dg|
        dg[:roles].push({ id: resque_worker.id, replicas: resque_worker.replicas })
      end
    end
  end

  def assert_release_count(current_count)
    project.kubernetes_releases.count.must_equal current_count
  end
end

