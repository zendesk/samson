require_relative '../test_helper'

describe CsvController do
  let(:deployer) { users(:deployer) }
  
  as_a_admin do
    describe "a GET to :index" do
      setup { get :index, format: format }
    
      describe "as html" do
        let(:format) { :html }
      
        it "renders the template" do
          assert_template :index
        end
      end
      
      describe "as JSON" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
        end
      end
    end
  end

  as_a_viewer do
    describe "a GET to :index" do
      setup { get :index, format: format }

      describe "as html for a user with no jobs" do
        let(:format) { :html }
      
        it "renders the template" do
          assert_template :index
        end
      end
        
      describe "as JSON for a user with no jobs" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          @response.body.must_equal "{\"status\":\"not-found\"}"
          assert_response 404
        end
      end
    end

    describe "a GET to :new" do
      it "renders the template" do
        get :new
        assert_template :new
      end
    end

    describe "a GET to :status for pending" do
      setup { get :status, id: csv_exports(:pending).id, format: format}
      
      describe "as html" do
        let(:format) { :html }
      
        it "renders the status template" do
          assert_template :status
        end
      end
      
      describe "as JSON" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
          @response.body.must_equal csv_exports(:pending).to_json
        end
      end
    end
    
    describe "a GET to :deleted for started" do
      setup { get :status, id: csv_exports(:deleted).id, format: format}
      
      describe "as html" do
        let(:format) { :html }
      
        it "renders the status template" do
          assert_template :status
        end
      end
      
      describe "as JSON" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response 404
          @response.body.must_equal "{\"status\":\"not-found\"}"
        end
      end
    end
  end

  as_a_deployer do
    describe "a POST to :create" do
      teardown do
        @csv_exports = CsvExport.where(user_id: deployer.id)
        @csv_exports.each do |csv_file|
          filename = "#{Rails.root}/export/#{csv_file.id}"
          File.delete(filename) if File.exist?(filename)
          csv_file.soft_delete!
        end
      end
    
      it "should create a new csv_export" do
        assert_difference 'CsvExport.count' do
          post :create, content: "deploys"
        end
      end
      
      it "redirects to status page" do
        post :create, content: "deploys"
        assert_redirected_to csv_status_path(CsvExport.last)
      end
    end

    describe "a Get to :download with file" do
      setup do
        post :create, content: "deploys"
        test_csv = CsvExport.last
        get :download, id: test_csv.id
      end
      
      teardown do
        @csv_exports = CsvExport.where(user_id: deployer.id)
        @csv_exports.each do |csv_file|
          filename = "#{Rails.root}/export/#{csv_file.id}"
          File.delete(filename) if File.exist?(filename)
          csv_file.soft_delete!
        end
      end
    
      it "receives the file" do
        @response.content_type.must_equal "text/csv"
      end
    end
    
    describe "a Get to :download where file doesn't exist" do
      describe "as pending" do
        it "redirects to :status" do
          csv_id = csv_exports(:pending).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
      
      describe "as started" do
        it "redirects to :status" do
          csv_id = csv_exports(:started).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
      
      describe "as finished with no file" do
        it "redirects to :status and updates deleted" do
          csv_id = csv_exports(:finished).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
      
      describe "as downloaded with no file" do
        it "redirects to :status and updates deleted" do
          csv_id = csv_exports(:downloaded).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
      
      describe "as deleted" do
        it "redirects to :status" do
          csv_id = csv_exports(:deleted).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
      
      describe "as failed" do
        it "redirects to :status" do
          csv_id = csv_exports(:failed).id
          get :download, id: csv_id
          assert_redirected_to csv_status_path(csv_id)
        end
      end
    end
  end
end
