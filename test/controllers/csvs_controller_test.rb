require_relative '../test_helper'

describe CsvsController do
  let(:deployer) { users(:deployer) }
  let(:export) { csv_exports(:pending) }

  describe "permissions test" do
    as_a_admin do
      describe "a GET to new" do
        it "renders the full admin menu and new page" do
          get :new
          @response.body.must_include "Environment variables"
          @response.body.must_include "Download Users CSV Report"
          @response.body.must_include "Reports"
          @response.body.must_include "Create Deploys CSV Report"
        end
      end
    end

    as_a_deployer do
      describe "a GET to new" do
        it "renders the limited admin menu and limited new page" do
          get :new
          @response.body.wont_include "Environment variables"
          @response.body.wont_include "Download Users CSV Report"
          @response.body.must_include "Reports"
          @response.body.must_include "Create Deploys CSV Report"
        end
      end
    end
  end

  as_a_deployer do
    describe "#Index" do
      describe "as html with exports" do
        it "renders the table of each status type" do
          create_exports
          get :index, format: :html
          assert_template :index
          index_page_includes_type :pending
          index_page_includes_type :started
          index_page_includes_type :finished
          index_page_includes_type :downloaded
          index_page_includes_type :failed
          index_page_includes_type :deleted
        end
      end

      describe "as html without exports" do
        it "responds with empty message" do
          CsvExport.delete_all
          get :index, format: :html
          assert_template :index
          @response.body.must_include "No current CSV Reports was found!"
        end
      end

      describe "as JSON with exports" do
        it "renders json" do
          create_exports
          get :index, format: :json
          @response.content_type.must_equal "application/json"
          @response.body.must_include CsvExport.all.to_json
        end
      end

      describe "as JSON without exports" do
        it "renders json" do
          CsvExport.delete_all
          get :index, format: :json
          @response.content_type.must_equal "application/json"
        end
      end
    end

    describe "#show" do
      def self.show_test(state)
        describe state do
          setup { export.update_attribute('status', state) }

          describe "as html" do
            it "renders html" do
              get :show, id: export.id, format: :html
              assert_template :show
              @response.body.must_include show_expected_html(state)
            end
          end

          describe "as json" do
            it "renders json" do
              get :show, id: export.id, format: :json
              @response.content_type.must_equal "application/json"
              @response.body.must_equal export.reload.to_json
            end
          end

          describe "as csv with no file" do
            setup do
              File.delete(export.full_filename) if File.exist?(export.full_filename)
              get :show, id: export.id, format: :csv
            end

            it "redirects to status" do
              assert_redirected_to csv_path(export)
            end

            if [:finished, :downloaded].include?(state) # Only run this test if ready
              it "changes state to deleted if ready" do
                assert export.reload.status? :deleted
              end
            end
          end

          if [:finished, :downloaded].include?(state)  # Only run these tests if ready
            describe "as csv with file" do
              setup do
                CsvExportJob.perform_now(export.id)
                export.update_attribute("status", state)
              end

              teardown { cleanup_files }

              it "receives file" do
                get :show, id: export.id, format: 'csv'
                @response.content_type.must_equal "text/csv"
                assert export.reload.status? :downloaded
              end
            end
          end
        end
      end

      show_test :pending
      show_test :started
      show_test :finished
      show_test :downloaded
      show_test :failed
      show_test :deleted

      describe "for invalid id" do
        describe "as html" do
          it "renders 404 page" do
            get :show, id: -9999, format: :html
            @response.body.must_include "The page you were looking for doesn't exist"
            assert_response 404
          end
        end

        describe "as json" do
          it "returns not found" do
            get :show, id: -9999, format: :json
            @response.content_type.must_equal "application/json"
            @response.body.must_include "not found"
            assert_response 404
          end
        end

        describe "as csv" do
          it "returns not found" do
            get :show, id: -9999, format: :csv
            @response.content_type.must_equal "text/csv"
            @response.body.must_include "not found"
            assert_response 404
          end
        end
      end
    end

    describe "a POST to create" do
      teardown { cleanup_files }
    
      it "should create a new csv_export and redirects to status" do
        assert_difference 'CsvExport.count' do
          post :create, content: "deploys"
        end
        assert_redirected_to csv_path(CsvExport.last)
      end
    end
  end

  def create_exports
    CsvExport.create(user: deployer, status: :started, content: 'deploys', filters: "{\"content\":\"deploys\"}") # pending already in fixtures
    CsvExport.create(user: deployer, status: :finished, content: 'deploys', filters: "{\"content\":\"deploys\"}")
    CsvExport.create(user: deployer, status: :downloaded, content: 'deploys', filters: "{\"content\":\"deploys\"}")
    CsvExport.create(user: deployer, status: :failed, content: 'deploys', filters: "{\"content\":\"deploys\"}")
    CsvExport.create(user: deployer, status: :deleted, content: 'deploys', filters: "{\"content\":\"deploys\"}")
  end

  def cleanup_files
    @csv_exports = CsvExport.all
    @csv_exports.each do |csv_file|
      filename = csv_file.full_filename
      File.delete(filename) if File.exist?(filename)
      csv_file.delete
    end
  end

  def index_page_includes_type(state)
    @response.body.must_include state.to_s
    @response.body.must_include index_link(state.to_s)
  end

  def index_link(state)
    csv = CsvExport.find_by(status: state)
    state == 'ready' ? csv_path(csv, format: 'csv') : csv_path(csv)
  end

  def show_expected_html(state)
    case state.to_s
      when 'deleted.'
        'has been deleted'
      when 'failed'
        'has failed.'
      when 'finished', 'downloaded'
        'ready for download'
      else
        'is being prepared'
    end
  end
end
