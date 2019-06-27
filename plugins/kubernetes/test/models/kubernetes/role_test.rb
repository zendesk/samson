# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Role do
  include GitRepoTestHelper

  def write_config(file, content)
    Dir.chdir(repo_temp_dir) do
      dir = File.dirname(file)
      Dir.mkdir(dir) if file.include?("/") && !File.exist?(dir)
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
  let(:pod) do
    {
      kind: 'Pod',
      apiVersion: 'v1',
      metadata: {name: 'foo', labels: {role: 'migrate', project: 'bar'}},
      spec: {containers: [{name: 'foo', resources: {limits: {cpu: '0.5', memory: '300M'}}}]}
    }
  end
  let(:config_content) do
    YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml'))
  end
  let(:config_content_yml) { config_content.map(&:to_yaml).join("\n") }

  describe 'validations' do
    it 'is valid' do
      assert_valid role
    end

    describe "service name" do
      let(:other) { kubernetes_roles(:resque_worker) }

      before do
        other.update_column(:service_name, 'abc')
        role.service_name = 'abc'
      end

      it "stores empty as nil to not run into duplication issues" do
        role.service_name = ''
        assert_valid role
        role.service_name.must_be_nil
      end

      it "is invalid with a already used service name" do
        refute_valid role
      end

      it "is valid with a already used service name that was deleted" do
        other.soft_delete!(validate: false)
        assert_valid role
      end
    end

    describe "name" do
      it 'is invalid with a name we could not use in kubernetes' do
        role.name = 'foo_bar'
        refute_valid role
      end
    end

    describe "resource_name" do
      before { role.manual_deletion_acknowledged = true }

      it "is invalid when blank" do
        role.resource_name = ""
        refute_valid role
      end

      it "is valid when filled with a valid name" do
        role.resource_name = "dfssd"
        assert_valid role
      end

      it "is invalid when it cannot be used in kubernetes" do
        role.resource_name = "sfsdf__F"
        refute_valid role
      end
    end

    describe "manual_deletion_acknowledged" do
      before { role.resource_name = 'XXX' }

      it "is invalid when not acknowledged" do
        refute_valid role
      end

      it "is valid when acknowledged" do
        role.manual_deletion_acknowledged = true
        assert_valid role
      end
    end
  end

  describe '.seed!' do
    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
      Kubernetes::Role.delete_all
      project.kubernetes_roles.clear
    end

    describe "with a correct role config" do
      before { write_config 'kubernetes/a.yml', config_content_yml }

      it 'creates a role' do
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.map(&:config_file).must_equal ["kubernetes/a.yml"]
      end

      it 'does not create duplicate roles' do
        Kubernetes::Role.seed! project, 'HEAD'
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.map(&:config_file).must_equal ["kubernetes/a.yml"]
      end

      it "re-creates deleted roles" do
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.each(&:soft_delete!)
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.where(deleted_at: nil).map(&:config_file).must_equal ["kubernetes/a.yml"]
      end
    end

    describe "with a job" do
      before do
        write_config 'kubernetes/a.yml', read_kubernetes_sample_file('kubernetes_job.yml')
      end

      it 'creates a role' do
        Kubernetes::Role.seed! project, 'HEAD'
        role = project.kubernetes_roles.first
        role.name.must_equal 'job-role'
      end
    end

    describe "with a pod" do
      before { write_config 'kubernetes/a.yml', pod.to_yaml }

      it 'creates a role' do
        Kubernetes::Role.seed! project, 'HEAD'
        role = project.kubernetes_roles.first
        role.name.must_equal 'migrate'
      end
    end

    describe "without a service" do
      before do
        config_content.pop
        write_config 'kubernetes/a.json', config_content.to_json
      end

      it 'creates a role' do
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.map(&:service_name).must_equal [nil]
      end

      it 'creates a role when another role without service already exists' do
        project.kubernetes_roles.create!(
          config_file: 'sdfsdf.yml',
          name: 'sdfsdf',
          service_name: nil,
          resource_name: 'ssddssd'
        )
        Kubernetes::Role.seed! project, 'HEAD'
        project.kubernetes_roles.map(&:service_name).must_equal [nil, nil]
      end
    end

    it 'shows an error when config is invalid' do
      config_content.push config_content.first # error: multiple primary resources
      write_config 'kubernetes/a.json', config_content.to_json
      assert_raises(Samson::Hooks::UserError) { Kubernetes::Role.seed! project, 'HEAD' }
      project.kubernetes_roles.must_equal []
    end

    it "allows not having a primary resource" do
      config_content[0][:kind] = "ConfigMap"
      write_config 'kubernetes/a.json', config_content.to_json
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:name).must_equal ["some-role"]
    end

    it "generates a unique resource_name when metadata.name is already in use" do
      project.update_column(:permalink, 'foo_bar') # check we remove _ correctly
      created = project.kubernetes_roles.create!(role.attributes)
      config_content[0]['metadata']['name'] = created.resource_name
      write_config 'kubernetes/a.json', config_content.to_json

      Kubernetes::Role.seed! project, 'HEAD'

      names = Kubernetes::Role.all.map(&:resource_name)
      names.must_equal ["test-app-server", "foo-bar-test-app-server"]
    end

    it "reads other file types" do
      write_config 'kubernetes/a.json', config_content.to_json
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:config_file).must_equal ["kubernetes/a.json"]
    end

    it "does not read other files" do
      write_config 'kubernetes.yml', config_content_yml
      write_config 'foobar/kubernetes.yml', config_content_yml
      e = assert_raises Samson::Hooks::UserError do
        Kubernetes::Role.seed! project, 'HEAD'
      end
      e.message.must_include "No configs found"
      project.kubernetes_roles.must_equal []
    end

    it "warns when nothing was found" do
      e = assert_raises Samson::Hooks::UserError do
        Kubernetes::Role.seed! project, 'DFSDSFSDFD'
      end
      e.message.must_include "No configs found"
    end

    it "can seed duplicate service names" do
      existing_name = config_content.last.fetch('metadata').fetch('name')
      created = project.kubernetes_roles.create!(role.attributes.merge('service_name' => existing_name))
      created.update_column(:project_id, 1234) # make sure we check in glboal scope
      write_config 'kubernetes/a.yml', config_content_yml
      Kubernetes::Role.seed! project, 'HEAD'
      names = Kubernetes::Role.all.map(&:service_name)
      names.last.must_match /#{existing_name}-change-me-\d+/
    end

    it "does not see service or resource when using manual naming" do
      project.create_kubernetes_namespace!(name: "foo")
      write_config 'kubernetes/a.json', config_content.to_json
      Kubernetes::Role.seed! project, 'HEAD'
      project.kubernetes_roles.map(&:resource_name).must_equal [nil]
      project.kubernetes_roles.map(&:service_name).must_equal [nil]
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

    describe "with uncommon config location" do
      before do
        execute_on_remote_repo "git rm #{role.config_file}" # remove file from git ls-files
        role.update_column(:config_file, 'foobar/foo.yml')
      end

      it "finds roles outside of the common locations" do
        write_config role.config_file, config_content_yml
        Kubernetes::Role.configured_for_project(project, 'HEAD').must_equal [role]
      end

      it "ignores when the role is configured but not in the repo" do
        Kubernetes::Role.configured_for_project(project, 'HEAD').must_equal []
      end
    end

    it "ignores when a role is in the repo, but not configured" do
      role.destroy!
      Kubernetes::Role.configured_for_project(project, 'HEAD').must_equal []
    end

    it "raises when a role is invalid so the deploy is cancelled" do
      assert config_content_yml.sub!('project: some-project', 'project: project-invalid')
      write_config role.config_file, config_content_yml

      assert_raises Samson::Hooks::UserError do
        Kubernetes::Role.configured_for_project(project, 'HEAD')
      end
    end

    it "ignores deleted roles" do
      other = project.kubernetes_roles.create!(
        config_file: 'foobar/foo.yml', name: 'xasdasd', resource_name: 'dsfsfsdf'
      )
      write_config other.config_file, config_content_yml
      other.soft_delete!(validate: false)

      Kubernetes::Role.configured_for_project(project, 'HEAD').must_equal [role]
    end
  end

  describe '#defaults' do
    before do
      GitRepository.any_instance.stubs(file_content: config_content_yml)
    end

    it "find defaults" do
      role.defaults.must_equal(
        replicas: 2,
        requests_cpu: 0.25,
        requests_memory: 50,
        limits_cpu: 0.5,
        limits_memory: 100
      )
    end

    it "finds in pod" do
      config_content_yml.replace(pod.to_yaml)
      role.defaults.must_equal(
        replicas: 0,
        requests_cpu: 0.5,
        requests_memory: 300,
        limits_cpu: 0.5,
        limits_memory: 300
      )
    end

    it "defaults to 1 replica" do
      assert config_content_yml.sub!('replicas: 2', 'foobar: 3')
      role.defaults[:replicas].must_equal 1
    end

    it "does not fail without spec" do
      labels = {project: 'some-project', role: 'some-role'}
      map = {
        kind: 'ConfigMap',
        apiVersion: 'v1',
        metadata: {name: 'datadog', labels: labels},
        namespace: 'default',
        labels: labels
      }.to_yaml
      config_content_yml.prepend("#{map}\n---\n")
      role.defaults.must_equal(
        replicas: 2,
        requests_cpu: 0.25,
        requests_memory: 50,
        limits_cpu: 0.5,
        limits_memory: 100
      )
    end

    it "finds values for any kind of resource" do
      assert config_content_yml.sub!('Deployment', 'Job')
      assert config_content_yml.sub!(/\n\n---.*/m, '')
      assert config_content_yml.sub!('containers:', "restartPolicy: Never\n      containers:")
      assert role.defaults
    end

    {
      '10000000' => 10,
      '10000K' => 10,
      '10000Ki' => 10,
      '10M' => 10,
      '10Mi' => 10,
      '10G' => 10 * 1000,
      '10.5G' => 10.5 * 1000,
      '10Gi' => 10737,
    }.each do |ram, expected|
      it "converts memory units #{ram}" do
        assert config_content_yml.sub!('100M', ram)
        role.defaults.try(:[], :limits_memory).must_equal expected
      end
    end

    it "ignores unknown memory units" do
      assert config_content_yml.sub!('100M', '200T')
      role.defaults.must_be_nil
    end

    it "ignores unknown cpu units" do
      assert config_content_yml.sub!('500m', '500x')
      role.defaults.must_be_nil
    end

    it "ignores without limits" do
      assert config_content_yml.sub!('limits', 'foos')
      role.defaults.must_be_nil
    end

    it "uses limits for requests memory when requests was unreadable" do
      assert config_content_yml.sub!('50M', '50x') # requests memory
      role.defaults[:requests_memory].must_equal role.defaults[:limits_memory]
    end

    it "ignores units that do not fit the metric" do
      assert config_content_yml.sub!('100M', '200m')
      role.defaults.must_be_nil
    end

    it "ignores when there is no config" do
      GitRepository.any_instance.stubs(file_content: nil)
      role.defaults.must_be_nil
    end

    it "ignores when config is invalid" do
      assert config_content_yml.sub!('Service', 'Deployment')
      refute role.defaults
    end
  end

  describe "#delete_kubernetes_deploy_group_roles" do
    it "cleanes up configs on delete so other validations do not run in to them" do
      Kubernetes::DeployGroupRole.create!(
        kubernetes_role: role,
        project: project,
        replicas: 1,
        requests_cpu: 0.5,
        requests_memory: 5,
        limits_cpu: 1,
        limits_memory: 10,
        deploy_group: deploy_groups(:pod2)
      )
      role.kubernetes_deploy_group_roles.wont_equal []
      role.soft_delete!(validate: false)
      role.reload.kubernetes_deploy_group_roles.must_equal []
    end
  end

  describe "#strip_config_file" do
    it "removes spaces from config files because that happens to often and leads to mysterious bugs" do
      role.config_file = ' whoops '
      role.save!
      role.config_file.must_equal 'whoops'
    end
  end

  describe "#manual_deletion_required?" do
    it "is not required when new" do
      refute Kubernetes::Role.new(service_name: "foo").manual_deletion_required?
    end

    it "is not required when adding" do
      role.service_name = "xxx"
      refute role.manual_deletion_required?
    end

    it "required when changing" do
      role.resource_name = "xxx"
      assert role.manual_deletion_required?
    end

    it "required when removing" do
      role.resource_name = nil
      assert role.manual_deletion_required?
    end
  end
end
