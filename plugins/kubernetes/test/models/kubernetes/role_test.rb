require_relative "../../test_helper"

SingleCov.covered! uncovered: 3

describe Kubernetes::Role do
  include GitRepoTestHelper

  def write_config(file, content)
    Dir.chdir(repo_temp_dir) do
      Dir.mkdir(File.dirname(file)) if file.include?("/")
      File.write(file, content)
    end
    commit
  end

  def commit
    execute_on_remote_repo <<-SHELL
        git add .
        git commit -m "second commit"
    SHELL
  end

  let(:role) { kubernetes_roles(:app_server) }
  let(:project) { role.project }
  let(:config_content) do
    [
      {
        'kind' => 'Deployment',
        'metadata' => {'labels' => {'role' => 'ROLE1'}},
        'spec' => {'replicas' => 1, 'template'=> {'spec' => {'containers' => [{'resources' => {'limits' => {'ram_mi' => 23, 'cpu_m' => 11.12}}}]}}},
        'strategy_type' => 'RollingUpdate'
      },
      {
        'kind' => 'Service',
        'metadata' => {'name' => 'SERVICE-NAME'}
      }
    ]
  end
  let(:config_content_yml) { config_content.map(&:to_yaml).join("\n") }

  describe 'validations' do
    it 'is valid by default' do
      assert_valid(role)
    end

    it 'test that CPU is valid' do
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = 'abc' })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = 0 })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.cpu = -2 })
    end

    it 'test that RAM is valid' do
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = 'abc' })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = 0 })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.ram = -2 })
    end

    it 'test validity of deploy strategy' do
      Kubernetes::Role::DEPLOY_STRATEGIES.each do |strategy|
        assert_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = strategy })
      end
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = nil })
      refute_valid(kubernetes_roles(:app_server).tap { |kr| kr.deploy_strategy = 'foo' })
    end
  end

  describe '#ram_with_units' do
    it 'works' do
      role.ram = 512
      role.ram_with_units.must_equal '512Mi'
    end
  end

  describe '.seed' do
    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
      Kubernetes::Role.delete_all
    end

    it 'creates a role' do
      write_config 'kubernetes/a.yml', config_content_yml
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:config_file).must_equal ["kubernetes/a.yml"]
    end

    it 'creates a role without a service' do
      config_content.pop
      write_config 'kubernetes/a.json', config_content.to_json
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:service_name).must_equal [nil]
    end

    it "reads other file types" do
      write_config 'kubernetes/a.json', config_content.to_json
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:config_file).must_equal ["kubernetes/a.json"]
    end

    it "does not read other files" do
      write_config 'kubernetes.yml', config_content_yml
      write_config 'foobar/kubernetes.yml', config_content_yml
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.must_equal []
    end

    it "does nothing on error" do
      Kubernetes::Role.seed! project, 'DFSDSFSDFD'
      project.kubernetes_roles.must_equal []
    end
  end

  describe '.configured_for_project' do
    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
      write_config role.config_file, config_content_yml
    end

    it "finds all roles that are deployed" do
      Kubernetes::Role.configured_for_project(project, 'HEAD').must_equal [role]
    end

    it "raises when a role is in the repo, but not configured" do
      role.soft_delete!
      assert_raises Samson::Hooks::UserError do
        Kubernetes::Role.configured_for_project(project, 'HEAD')
      end
    end
  end
end
