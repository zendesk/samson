require_relative '../test_helper'

describe CsvsController do
  let(:deployer) { users(:deployer) }
  let(:export) { csv_exports(:pending) }

  describe "permissions test" do
    as_a_admin do
      describe "a GET to new" do
        it "renders the page with user link & admin menu" do
          get :new
          assert_template :new
          assert @response.body.include? "Create Deploys CSV Report"
          assert @response.body.include? "Download Users CSV Report"
          assert @response.body.include? "Admin"
          assert @response.body.include? "Environment variables"
        end
      end
    end

    as_a_deployer do
      describe "a GET to new" do
        it "renders the page without user link & limited admin menu" do
          get :new
          assert_template :new
          assert @response.body.include? "Create Deploys CSV Report"
          refute @response.body.include? "Download Users CSV Report"
          assert @response.body.include? "Admin"
          refute @response.body.include? "Environment variables"
        end
      end
    end
  end

  as_a_admin do
    describe "a GET to index for a user with csv exports" do
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
    describe "a GET to index for a user with no csv exports" do
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
          @response.body.must_equal "{\"csvs\":[]}"
          assert_response :ok
        end
      end
    end

    describe "a GET to show for pending" do
      setup { get :show, id: export.id, format: format}
      
      describe "as html" do
        let(:format) { :html }
      
        it "renders the status template" do
          assert_template :show
          @response.body.must_include "being prepared"
        end
      end
      
      describe "as JSON" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
          @response.body.must_equal export.to_json
        end
      end
    end

    describe "a GET to show for deleted" do
      setup do
        @csv_export = CsvExport.find(export.id)
        @csv_export.deleted!
        get :show, id: @csv_export.id, format: format
      end
      
      describe "as html" do
        let(:format) { :html }
      
        it "renders the status template" do
          assert_template :show
          @response.body.must_include "deleted"
        end
      end
      
      describe "as JSON" do
        let(:format) { :json }
        
        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
          @csv_export.reload
          @response.body.must_equal @csv_export.to_json
        end
      end
    end

    describe "a GET to show for invalid" do
      setup { get :show, id: -1, format: format }

      describe "as html" do
        let(:format) { :html }

        it "redirects to index with error flash" do
          assert_redirected_to csvs_path
          flash[:error].must_equal "The CSV export does not exist."
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

    describe "a GET to show for finished" do
      setup do
        @csv_export = CsvExport.find(export.id)
        @csv_export.finished!
        get :show, id: @csv_export.id, format: format
      end

      describe "as html" do
        let(:format) { :html }

        it "renders the status template" do
          assert_template :show
          @response.body.must_include "download"
          @response.body.must_include csv_path(id: @csv_export.id, format: 'csv')
        end
      end

      describe "as JSON" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
          @csv_export.reload
          @response.body.must_equal @csv_export.to_json
        end
      end
    end

    describe "a GET to show for downloaded" do
      setup do
        @csv_export = CsvExport.find(export.id)
        @csv_export.downloaded!
        get :show, id: @csv_export.id, format: format
      end

      describe "as html" do
        let(:format) { :html }

        it "renders the status template" do
          assert_template :show
          @response.body.must_include "download"
          @response.body.must_include csv_path(id: @csv_export.id, format: 'csv')
        end
      end

      describe "as JSON" do
        let(:format) { :json }

        it "renders json" do
          assert_equal "application/json", @response.content_type
          assert_response :ok
          @csv_export.reload
          @response.body.must_equal @csv_export.to_json
        end
      end
    end
  end

  as_a_deployer do
    describe "a POST to create" do
      teardown do
        @csv_exports = CsvExport.where(user_id: deployer.id)
        @csv_exports.each do |csv_file|
          filename = "#{Rails.root}/export/#{csv_file.id}"
          File.delete(filename) if File.exist?(filename)
          csv_file.delete
        end
      end
    
      it "should create a new csv_export and redirects to status" do
        assert_difference 'CsvExport.count' do
          post :create, content: "deploys"
        end
        assert_redirected_to csv_path(CsvExport.last)
      end
    end

    describe "a Get to show as csv with file" do
      setup do
        post :create, content: "deploys"
        @test_csv = CsvExport.last
      end
      
      teardown do
        @csv_exports = CsvExport.where(user_id: deployer.id)
        @csv_exports.each do |csv_file|
          filename = "#{Rails.root}/export/#{csv_file.id}"
          File.delete(filename) if File.exist?(filename)
          csv_file.delete
        end
      end
    
      it "receives the file when finished" do
        get :show, id: @test_csv.id, format: 'csv'
        @response.content_type.must_equal "text/csv"
        @test_csv.reload
        assert @test_csv.downloaded?
      end

      it "receives the file when downloaded" do
        @test_csv.downloaded!
        get :show, id: @test_csv.id, format: 'csv'
        @response.content_type.must_equal "text/csv"
        @test_csv.reload
        assert @test_csv.downloaded?
      end
    end

    describe "a Get to show as csv with no file" do
      setup { @csv_export = CsvExport.find(export.id) }

      describe "as pending" do
        it "redirects to show" do
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.pending?
        end
      end
      
      describe "as started" do
        it "redirects to show" do
          @csv_export.started!
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.started?
        end
      end
      
      describe "as finished with no file" do
        it "redirects to show and updates deleted" do
          @csv_export.finished!
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.deleted?
        end
      end
      
      describe "as downloaded with no file" do
        it "redirects to show and updates deleted" do
          @csv_export.deleted!
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.deleted?
        end
      end
      
      describe "as deleted" do
        it "redirects to show" do
          @csv_export.deleted!
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.deleted?
        end
      end

      describe "as failed" do
        it "redirects to show" do
          @csv_export.failed!
          get :show, id: @csv_export.id, format: 'csv'
          assert_redirected_to csv_path(@csv_export)
          @csv_export.reload
          assert @csv_export.failed?
        end
      end

      describe "as invalid" do
        it "redirects to index with error flash" do
          get :show, id: -9999, format: 'csv'
          assert_redirected_to csvs_path
          flash[:error].must_equal "The CSV export does not exist."
        end
      end
    end
  end
end
