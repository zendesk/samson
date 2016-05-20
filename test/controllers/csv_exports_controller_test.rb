require_relative '../test_helper'

SingleCov.covered!

describe CsvExportsController do
  let(:viewer) { users(:viewer) }
  let(:export) { csv_exports(:pending) }

  describe "permissions test" do
    as_a_admin do
      describe "#new" do
        it "renders the full admin menu and new page" do
          get :new
          @response.body.must_include "Environment variables"
          @response.body.must_include "Download Users CSV Report"
          @response.body.must_include "Reports"
          @response.body.must_include "Create Deploys CSV Report"
        end
      end
    end

    as_a_viewer do
      describe "#new" do
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

  as_a_viewer do
    describe "#index" do
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

    describe "#new" do
      before do
        p = projects(:test).dup
        p.name = "Other"
        p.save!(validate: false)
      end

      it "renders form options" do
        get :new
        @response.body.must_include ">Other</option>"
        @response.body.must_include ">Project</option>"
      end
    end

    describe "#show" do
      def self.show_test(state)
        describe state do
          before { export.update_attribute('status', state) }

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
            before do
              export.delete_file
              get :show, id: export.id, format: :csv
            end

            it "redirects to status" do
              assert_redirected_to export
            end

            if [:finished, :downloaded].include?(state)
              it "changes state to deleted if ready" do
                assert export.reload.status? :deleted
              end
            else
              it "does not change state if not ready" do
                assert export.reload.status? state
              end
            end
          end

          if [:finished, :downloaded].include?(state) # Only run these tests if ready
            describe "as csv with file" do
              before do
                CsvExportJob.perform_now(export)
                export.update_attribute("status", state)
              end

              after { cleanup_files }

              it "receives file" do
                get :show, id: export.id, format: 'csv'
                @response.content_type.must_equal "text/csv"
                export.reload.status.must_equal "downloaded"
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
          it "raises ActiveRecord::RecordNotFound" do
            assert_raise(ActiveRecord::RecordNotFound) do
              get :show, id: -9999, format: :html
            end
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

    describe "#create" do
      after { cleanup_files }

      it "with no filters creates a new csv_export and redirects to status" do
        assert_difference 'CsvExport.count' do
          post :create
        end
        assert_redirected_to CsvExport.last
      end

      it "with valid filters creates a new csv_export, with correct filters and redirect to status" do
        filter = {
          start_date: "2010-01-01", end_date: "2015-12-31", production: "Yes", status: "succeeded",
          project: projects(:test).id.to_s
        }
        assert_difference 'CsvExport.count' do
          post :create, filter
        end
        assert_redirected_to CsvExport.last
        csv_filter = CsvExport.last.filters
        csv_filter.keys.must_include "deploys.created_at"
        csv_filter.keys.must_include "stages.production"
        csv_filter.keys.must_include "jobs.status"
        csv_filter.keys.must_include "stages.project_id"
        start_date = Date.parse(filter[:start_date])
        end_date = Date.parse(filter[:end_date])
        csv_filter["deploys.created_at"].must_equal start_date..end_date
        csv_filter["stages.production"].must_equal true
        csv_filter["jobs.status"].must_equal "succeeded"
        csv_filter["stages.project_id"].must_equal projects(:test).id
      end

      it "with production No filter creates a correct filter" do
        filter = { production: "No"}
        post :create, filter
        csv_filter = CsvExport.last.filters
        csv_filter["stages.production"].must_equal false
      end

      it "with production blank filter does not have stages.production filter" do
        filter = { production: ""}
        post :create, filter
        csv_filter = CsvExport.last.filters
        refute csv_filter.keys.include?"stages.production"
      end

      it "raises for invalid params" do
        create_fail_test(ArgumentError, start_date: '2000-13-13')
        create_fail_test(ArgumentError, end_date: '2015-13-31')
        create_fail_test("Invalid production filter foo", production: 'foo')
        create_fail_test("Invalid status filter foo", status: 'foo')
        create_fail_test("Invalid project id foo", project: "foo")
      end
    end
  end

  def create_exports
    CsvExport.create(user: viewer, status: :started) # pending already in fixtures
    CsvExport.create(user: viewer, status: :finished)
    CsvExport.create(user: viewer, status: :downloaded)
    CsvExport.create(user: viewer, status: :failed)
    CsvExport.create(user: viewer, status: :deleted)
  end

  def cleanup_files
    CsvExport.find_each(&:destroy!)
  end

  def index_page_includes_type(state)
    @response.body.must_include state.to_s
    @response.body.must_include index_link(state.to_s)
  end

  def index_link(state)
    csv = CsvExport.find_by(status: state)
    state == 'ready' ? csv_export_path(csv, format: 'csv') : csv_export_path(csv)
  end

  def show_expected_html(state)
    case state.to_s
    when 'deleted'
      'has been deleted'
    when 'failed'
      'has failed.'
    when 'finished', 'downloaded'
      'Download'
    else
      'is being prepared'
    end
  end

  def create_fail_test(message, filter)
    assert_raise(message) do
      post :create, filter
    end
  end
end
