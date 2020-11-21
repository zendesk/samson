# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::StagesController do
  let(:deploy_group_role) { kubernetes_deploy_group_roles(:test_pod1_app_server) }
  let(:deploy_group) { deploy_group_role.deploy_group }
  let(:worker_role) { Kubernetes::Role.find_by(name: "resque-worker") }
  let(:app_role) { deploy_group_role.kubernetes_role }
  let(:project) { stage.project }
  let(:stage) { stages(:test_staging) }
  let(:git_sha) { SecureRandom.hex(40) }

  unauthorized :get, :manifest_preview, project_id: 1, id: 1

  as_a :admin do
    before do
      stage.update(deploy_groups: [deploy_group])

      stage.kubernetes_stage_roles.create(kubernetes_role: worker_role, ignored: true)

      GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', git_sha, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))
      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)
      Kubernetes::RoleValidator.any_instance.stubs(:validate)
      Kubernetes::RoleValidator.stubs(:validate_groups)
      Kubernetes::Role.stubs(:configured_for_project).returns([app_role])
    end

    describe '#manifest_preview' do
      it 'fails if reference invalid' do
        GitRepository.any_instance.expects(:commit_from_ref)
        get :manifest_preview, params: {project_id: project.id, id: stage.id}
        assert_response 400, '# Git reference not found'
      end

      it 'captures template validation errors' do
        Kubernetes::DeployExecutor.any_instance.stubs(:preview_release_docs).raises(Samson::Hooks::UserError, "foobar")
        get :manifest_preview, params: {project_id: project.id, id: stage.id}
        assert_response 400, '# foobar'
      end

      it 'builds kubernetes manifest' do
        GitRepository.any_instance.expects(:commit_from_ref).returns(git_sha)

        get :manifest_preview, params: {project_id: project.id, id: stage.id}
        assert_response 200
        yaml = YAML.load_stream(response.body)
        yaml.dig(0, "metadata", "name").must_equal "test-app-server"
        yaml.dig(0, "metadata", "namespace").must_equal "pod1"
        yaml.size.must_equal 2
      end
    end
  end
end
