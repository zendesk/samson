# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CsvExportJob do
  let(:deployer) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:deploy_export_job) { csv_exports(:pending) }

  it "enqueues properly" do
    assert_enqueued_jobs 1 do
      CsvExportJob.perform_later(deploy_export_job)
    end
  end

  it "cleans up old jobs" do
    old = CsvExport.create!(user: deployer, filters: {})
    old.update_attributes(created_at: DateTime.now - 1.year, updated_at: DateTime.now - 1.year)
    old_id = old.id

    CsvExportJob.perform_now(deploy_export_job)
    assert_raises(ActiveRecord::RecordNotFound) { CsvExport.find(old_id) }
  end

  describe "Error Handling" do
    before do
      FileUtils.mkdir_p(File.dirname(deploy_export_job.path_file))
      File.chmod(0000, File.dirname(deploy_export_job.path_file))
    end
    after { File.chmod(0755, File.dirname(deploy_export_job.path_file)) }

    it "sets :failed" do
      CsvExportJob.perform_now(deploy_export_job)
      assert deploy_export_job.status?('failed'), "Not Finished"
    end
  end

  describe "Job executes for deploy csv" do
    after { deploy_export_job.delete_file }

    it "finishes with file" do
      CsvExportJob.perform_now(deploy_export_job)
      job = CsvExport.find(deploy_export_job.id)
      assert job.status?('finished'), "Not Finished"
      assert File.exist?(job.path_file), "File Not exist"
    end

    describe "with Deploy Groups production filter (from environment)" do
      before do
        stages(:test_production).update_attribute(:production, nil)
        stages(:test_staging).update_attribute(:production, nil)
        DeployGroup.stubs(enabled?: true)
      end

      it "filters the report with known production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'environments.production': true, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end

      it "filters the report with known non-production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'environments.production': false, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end
    end

    describe "with Deploy Groups production filter (from stage)" do
      before do
        DeployGroup.stubs(enabled?: true)
        DeployGroupsStage.delete_all
      end

      it "filters the report with known production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'environments.production': true, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end

      it "filters the report with known non-production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'environments.production': false, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end
    end

    describe "with Deploy Groups disabled production filter" do
      it "creates deploys csv file accurately and completely" do
        completeness_test({}, 3)
      end

      it "filters the report with known production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'stages.production': true, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end

      it "filters the report with known non-production activity completely" do
        filter = {
          'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.parse(Date.today.to_s + "T23:59:59Z")),
          'stages.production': false, 'jobs.status': 'succeeded', 'stages.project_id': project.id
        }
        completeness_test(filter, 1)
      end

      it "has no results for date range after deploys" do
        filter = {'deploys.created_at': (DateTime.new(2015, 12, 31)..DateTime.parse(Date.today.to_s + "T23:59:59Z"))}
        completeness_test(filter, 0)
      end

      it "has no results for date range before deploys" do
        filter = {'deploys.created_at': (DateTime.new(1900, 1, 1)..DateTime.new(2000, 1, 1, 23, 59, 59))}
        completeness_test(filter, 0)
      end

      it "has no results for statuses with no fixtures" do
        filter = {'jobs.status': 'failed'}
        completeness_test(filter, 1)
      end

      it "has no results for non-existant project" do
        filter = {'stages.project_id': -999}
        completeness_test(filter, 0)
      end

      it "has no results for non-production with no valid non-prod deploy" do
        deploys(:succeeded_test).delete
        filter = {'stages.production': false}
        completeness_test(filter, 1)
      end

      it "sends mail" do
        assert_difference('ActionMailer::Base.deliveries.size', 1) do
          CsvExportJob.perform_now(deploy_export_job)
        end
      end

      it "doesn't send mail when user is invalid" do
        deploy_export_job.update_attribute('user_id', -999)
        assert_difference('ActionMailer::Base.deliveries.size', 0) do
          CsvExportJob.perform_now(deploy_export_job)
          assert deploy_export_job.email.nil?
        end
      end
    end
  end

  def completeness_test(filters, expected_count)
    deploy_export_job.update_attribute(:filters, filters)
    CsvExportJob.perform_now(deploy_export_job)
    filename = deploy_export_job.reload.path_file

    csv_response = CSV.read(filename)
    csv_response.shift # Remove Header in file
    csv_response.pop # Remove filter summary row
    deploycount = csv_response.pop.pop.to_i # Remove summary row and extract count
    expected_count.must_equal deploycount
    deploycount.must_equal csv_response.length
  end
end
