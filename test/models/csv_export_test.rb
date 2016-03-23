require_relative '../test_helper'

describe CsvExport do
  let(:user) { users(:deployer) }

  describe "CsvExport" do
    setup { @csv_export = CsvExport.create( user: user, filters: "{}" ) }
    
    it "sets pending and responds correctly" do
      @csv_export.status! :pending
      @csv_export.status.must_equal "pending"
      assert @csv_export.status? "pending"
      refute @csv_export.status? "ready"
    end
    
    it "sets started and responds correctly" do
      @csv_export.status! :started
      @csv_export.status.must_equal "started"
      assert @csv_export.status? "started"
      refute @csv_export.status? "ready"
    end
    
    it "sets finished and responds correctly" do
      @csv_export.status! :finished
      @csv_export.status.must_equal "finished"
      assert @csv_export.status? "finished"
      assert @csv_export.status? "ready"
    end
    
    it "sets downloaded and responds correctly" do
      @csv_export.status! :downloaded
      @csv_export.status.must_equal "downloaded"
      assert @csv_export.status? "downloaded"
      assert @csv_export.status? "ready"
    end
    
    it "sets failed and responds correctly" do
      @csv_export.status! :failed
      @csv_export.status.must_equal "failed"
      assert @csv_export.status? "failed"
      refute @csv_export.status? "ready"
    end
    
    it "sets deleted and responds correctly" do
      @csv_export.status! :deleted
      @csv_export.status.must_equal "deleted"
      assert @csv_export.status? "deleted"
      refute @csv_export.status? "ready"
    end

    it "raises invalid status" do
      assert_raise("Invalid Status") do
        @csv_export.status! "hello_world"
      end
    end

    it "status? responds to symbolics" do
      @csv_export.status! :finished
      assert @csv_export.status? :ready
      assert @csv_export.status? :finished
    end

    it "status! responds to string" do
      @csv_export.status! "finished"
      @csv_export.status.must_equal "finished"
    end
    
    it "sets filename if not assigned" do
      assert_not_empty @csv_export.download_name
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
      end
    end

    describe "file_delete" do
      setup do
        @filename = @csv_export.path_file
        File.new(@filename, 'w')
      end

      teardown do
        File.delete(@filename) if File.exist?(@filename)
      end

      it "deletes file when file_delete called" do
        assert File.exists?(@filename), "File not created in setup"
        @csv_export.file_delete
        refute File.exists?(@filename), "File not removed by file_delete"
      end

      it "deletes file when destroy called" do
        assert File.exists?(@filename), "File not created in setup"
        @csv_export.destroy
        refute File.exists?(@filename), "File not removed by destroy"
      end
    end
  end
end
