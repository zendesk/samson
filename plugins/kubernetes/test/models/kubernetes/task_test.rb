require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::Task do
  include GitRepoTestHelper

  def write_config(file, content)
    Dir.chdir(repo_temp_dir) do
      dir = File.dirname(file)
      FileUtils.mkdir_p(dir) if file.include?("/") && !File.exist?(dir)
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

  let(:task) { kubernetes_tasks(:db_migrate) }
  let(:project) { task.project }
  let(:config_content) do
    {
      'kind' => 'Job',
      'metadata' => {'labels' => {'task' => 'MIGRATE'}},
    }
  end
  let(:config_content_yml) { config_content.to_yaml }

  describe 'validations' do
    it 'is valid' do
      assert_valid task
    end
  end

  describe '.seed' do
    before do
      create_repo_without_tags
      project.repository_url = repo_temp_dir
      Kubernetes::Task.delete_all
    end

    describe "with a correct role config" do
      before { write_config 'kubernetes/jobs/a.yml', config_content_yml }

      it 'creates a task' do
        Kubernetes::Task.seed! project, 'HEAD'
        project.kubernetes_tasks.map(&:config_file).must_equal ["kubernetes/jobs/a.yml"]
      end

      it 'does not create duplicate roles' do
        Kubernetes::Task.seed! project, 'HEAD'
        Kubernetes::Task.seed! project, 'HEAD'
        project.kubernetes_tasks.map(&:config_file).must_equal ["kubernetes/jobs/a.yml"]
      end
    end

    it "does nothing on error" do
      Kubernetes::Task.seed! project, 'DFSDSFSDFD'
      project.kubernetes_tasks.must_equal []
    end

    it "can seed without task label" do
      assert config_content.fetch('metadata').delete('labels')
      write_config 'kubernetes/jobs/a.json', config_content.to_json
      Kubernetes::Task.seed! project, 'HEAD'
      project.kubernetes_tasks.map(&:config_file).must_equal ["kubernetes/jobs/a.json"]
    end
  end

  describe '#kubernetes_jobs' do
    it "sorts them by created_at" do
      task.kubernetes_jobs.to_sql.must_include 'ORDER BY `kubernetes_jobs`.`created_at` DESC'
    end
  end
end
