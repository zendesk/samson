require_relative '../test_helper'

describe CsvExport do
  let(:user) { users(:deployer) }

  describe "new CsvExport" do
    setup { @csv_export = CsvExport.create( user: user, content: "deploys" ) }
    
    it "sets pending and responds correctly" do
      @csv_export.pending!
      @csv_export.status.must_equal "pending"
      assert @csv_export.pending?
    end
    
    it "sets started and responds correctly" do
      @csv_export.started!
      @csv_export.status.must_equal "started"
      assert @csv_export.started?
    end
    
    it "sets finished and responds correctly" do
      @csv_export.finished!
      @csv_export.status.must_equal "finished"
      assert @csv_export.finished?
    end
    
    it "sets downloaded and responds correctly" do
      @csv_export.downloaded!
      @csv_export.status.must_equal "downloaded"
      assert @csv_export.downloaded?
    end
    
    it "sets failed and responds correctly" do
      @csv_export.failed!
      @csv_export.status.must_equal "failed"
      assert @csv_export.failed?
    end
    
    it "sets deleted and responds correctly" do
      @csv_export.deleted!
      @csv_export.status.must_equal "deleted"
      assert @csv_export.deleted?
    end
    
    it "sets filename if not assigned" do
      assert_not_empty @csv_export.filename
    end

    describe "returns users email" do
      it "for user not deleted" do
        @csv_export.email.must_equal user.email
      end
      
      it "returns null for invalid user" do
        @csv_export.update_attribute(:user_id, -99999)
        assert @csv_export.email.nil?
      end
    end
  end
end