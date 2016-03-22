require_relative '../test_helper'

describe CsvExportJob do
  let(:deployer) { users(:deployer) }
  let(:project) { projects(:test)}
  let(:deploy_export_job) { CsvExport.create(user: deployer, content: 'deploys', filters: "{\"content\":\"deploys\"}") }
  let(:invalid_export_job) { CsvExport.create(user: deployer, content: 'deploy', filters: "{\"content\":\"deploys\"}") }
  
  it "enqueues properly" do
    assert_enqueued_jobs 1 do
      CsvExportJob.perform_later(deploy_export_job.id)
    end
  end
  
  describe "Job executes for deploy csv" do
    teardown do
      job = CsvExport.find(deploy_export_job.id)
      filename = job.full_filename
      File.delete(filename) if File.exist?(filename)
    end
    
    it "finishes with file" do
      CsvExportJob.perform_now(deploy_export_job.id)
      job = CsvExport.find(deploy_export_job.id)
      assert job.status?('finished'), "Not Finished"
      assert File.exist?(job.full_filename), "File Not exist"
    end
    
    it "creates deploys csv file accurately and completely" do
      accuracy_test( {content: "deploys"}, {})
    end

    it "filters the report with known activity accurately and completely" do
      filter = {start_date: {year: 2014, month: 1, day:1},
        end_date: {year: 2014, month: 2, day:1}, production: 'Yes',
        status: ['succeeded'], project: project.id}
      t_filter = { 'deploys.created_at': (Date.civil(2014,1,1)..Date.civil(2014,2,1)),
        'stages.production': true, 'jobs.status': ['succeeded'],
        'stages.project_id': project.id}
      accuracy_test( filter, t_filter)
    end

    it "accurately has no results for date range after deploys" do
      filter = {start_date: {year: 2015, month: 1, day:1}}
      empty_test(filter)
    end

    it "accurately has no results for date range before deploys" do
      filter = {end_date: {year: 2013, month: 1, day:1}}
      empty_test(filter)
    end

    it "accurately has no results for statuses with no fixtures" do
      filter = {status: ['running', 'failed', 'errored', 'cancelling', 'cancelled']}
      empty_test(filter)
    end

    it "accurately has no results for non-existant project" do
      filter = {project: -999}
      empty_test(filter)
    end

    it "sends mail" do
      assert_difference('ActionMailer::Base.deliveries.size', 1) do
        CsvExportJob.perform_now(deploy_export_job.id)
      end
    end

    it "doesn't send mail when user is invalid" do
      deploy_export_job.update_attribute('user_id', -999)
      assert_difference('ActionMailer::Base.deliveries.size', 0) do
        CsvExportJob.perform_now(deploy_export_job.id)
        assert deploy_export_job.email.nil?
      end
    end
  end
  
  describe "Job executes for invalid csv export type" do
    teardown do
      job = CsvExport.find(invalid_export_job.id)
      filename = job.full_filename
      File.delete(filename) if File.exist?(filename)
    end

    test "fails with no file" do
      CsvExportJob.perform_now(invalid_export_job.id)
      job = CsvExport.find(invalid_export_job.id)
      assert job.status?('failed'), "Not Failed"
      refute File.exist?(job.full_filename), "File was created"
    end
  end

  def accuracy_test(filters, test_filter)
    deploy_export_job.update_attribute(:filters, filters.to_json)
    CsvExportJob.perform_now(deploy_export_job.id)
    filename = deploy_export_job.reload.full_filename

    csv_response = CSV.read(filename)
    csv_response.shift  # Remove Header in file
    csv_response.pop # Remove filter summary row
    deploycount = csv_response.pop.pop.to_i # Remove summary row and extract count
    if test_filter == {}
      Deploy.joins(:stage, :job).all.count.must_equal deploycount
    else
      Deploy.joins(:stage, :job).where(test_filter).count.must_equal deploycount
    end
    deploycount.must_equal csv_response.length
    assert_not_empty csv_response
    csv_response.each do |d|
      deploy_info = Deploy.find_by(id: d[0])
      deploy_info.wont_be_nil
      deploy_info.project.name.must_equal d[1]
      deploy_info.summary.must_equal d[2]
      deploy_info.commit.must_equal d[3]
      deploy_info.job.status.must_equal d[4]
      deploy_info.updated_at.to_s.must_equal d[5]
      deploy_info.start_time.to_s.must_equal d[6]
      deploy_info.job.user.name.must_equal d[7]
      deploy_info.job.user.try(:email).must_equal d[8]
      deploy_info.csv_buddy.must_equal d[9]
      deploy_info.buddy_email.must_equal d[10]
      deploy_info.stage.production.to_s.must_equal d[11]
      deploy_info.stage.bypass_buddy_check.to_s.must_equal d[12]
    end
  end

  def empty_test(filters)
    deploy_export_job.update_attribute(:filters, filters.to_json)
    CsvExportJob.perform_now(deploy_export_job.id)
    filename = deploy_export_job.reload.full_filename

    csv_response = CSV.read(filename)
    csv_response.shift  # Remove Header in file
    csv_response.pop # Remove filter summary row
    deploycount = csv_response.pop.pop.to_i # Remove summary row and extract count
    deploycount.must_equal 0
    deploycount.must_equal csv_response.length
  end
end
