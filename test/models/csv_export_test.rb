require_relative '../test_helper'

describe CsvExport do
  let(:user) { users(:deployer) }

  describe "CsvExport" do
    setup { @csv_export = CsvExport.create( user: user, content: "deploys", filters: "{\"content\":\"deploys\"}" ) }
    
    it "sets pending and responds correctly" do
      @csv_export.pending!
      @csv_export.status.must_equal "pending"
      assert @csv_export.status? "pending"
      refute @csv_export.status? "ready"
    end
    
    it "sets started and responds correctly" do
      @csv_export.started!
      @csv_export.status.must_equal "started"
      assert @csv_export.status? "started"
      refute @csv_export.status? "ready"
    end
    
    it "sets finished and responds correctly" do
      @csv_export.finished!
      @csv_export.status.must_equal "finished"
      assert @csv_export.status? "finished"
      assert @csv_export.status? "ready"
    end
    
    it "sets downloaded and responds correctly" do
      @csv_export.downloaded!
      @csv_export.status.must_equal "downloaded"
      assert @csv_export.status? "downloaded"
      assert @csv_export.status? "ready"
    end
    
    it "sets failed and responds correctly" do
      @csv_export.failed!
      @csv_export.status.must_equal "failed"
      assert @csv_export.status? "failed"
      refute @csv_export.status? "ready"
    end
    
    it "sets deleted and responds correctly" do
      @csv_export.deleted!
      @csv_export.status.must_equal "deleted"
      assert @csv_export.status? "deleted"
      refute @csv_export.status? "ready"
    end

    it "status responds to symbolics" do
      @csv_export.finished!
      assert @csv_export.status? :ready
      assert @csv_export.status? :finished
    end
    
    it "sets filename if not assigned" do
      assert_not_empty @csv_export.filename
    end

    describe "# email" do
      it "for valid user" do
        @csv_export.email.must_equal user.email
      end
      
      it "null for invalid user" do
        @csv_export.update_attribute(:user_id, -99999)
        assert @csv_export.email.nil?
      end
    end

    describe "# filters" do
      it "returns a ruby object" do
        assert @csv_export.filters.class.must_equal Hash.new.class
        assert @csv_export.filters[:content] = "deploys"
      end
    end
  end
end
