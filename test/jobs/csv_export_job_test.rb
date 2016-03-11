require_relative '../test_helper'

describe CsvExportJob do
  let(:deployer) { users(:deployer) }
  let(:deploy_export_job) { CsvExport.create(user: deployer, content: 'deploys') }
  let(:invalid_export_job) { CsvExport.create(user: deployer, content: 'deploy') }
  
  it "enqueues properly" do
    assert_enqueued_jobs 1 do
      CsvExportJob.perform_later(deploy_export_job.id)
    end
  end
  
  describe "Job executes for deploy csv" do
    teardown do
      job = CsvExport.find(deploy_export_job.id)
      filename = "#{Rails.root}/export/#{job.id}"
      File.delete(filename) if File.exist?(filename)
    end
    
    it "finishes with file" do
      CsvExportJob.perform_now(deploy_export_job.id)
      job = CsvExport.find(deploy_export_job.id)
      filename = "#{Rails.root}/export/#{job.id}"
      assert job.finished?, "Not Finished"
      assert File.exist?(filename), "File Not exist"
    end
    
    it "creates deploys csv accurately and completely" do
      CsvExportJob.perform_now(deploy_export_job.id)
      job = CsvExport.find(deploy_export_job.id)
      filename = "#{Rails.root}/export/#{job.id}"
      assert File.exist?(filename), "File Not exist"

      csv_response = CSV.read(filename)
      csv_headers = csv_response.shift
      deploycount = csv_headers.pop.to_i
      Deploy.joins(:stage).count.must_equal deploycount
      deploycount.must_equal csv_response.length
      assert_not_nil csv_response
      csv_response.each do |d|
        deploy_info = Deploy.find_by(id: d[0])
        deploy_info.wont_be_nil
        deploy_info.project.name.must_equal d[1]
        deploy_info.summary.must_equal d[2]
        deploy_info.updated_at.to_s.must_equal d[3]
        deploy_info.start_time.to_s.must_equal d[4]
        deploy_info.job.user.name.must_equal d[5]
        deploy_info.csv_buddy.must_equal d[6]
        deploy_info.stage.production.to_s.must_equal d[7]
      end
    end
  end
  
  describe "Job executies for invalid csv" do
    teardown do
      job = CsvExport.find(invalid_export_job.id)
      filename = "#{Rails.root}/export/#{job.id}"
      File.delete(filename) if File.exist?(filename)
    end

    test "fails with no file" do
      CsvExportJob.perform_now(invalid_export_job.id)
      job = CsvExport.find(invalid_export_job.id)
      filename = "#{Rails.root}/export/#{job.id}"
      assert job.failed?, "Not Failed"
      refute File.exist?(filename), "File was created"
    end
  end
end
