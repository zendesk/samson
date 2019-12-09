# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe CsvExportsController do
  let(:viewer) { users(:viewer) }
  let(:export) { csv_exports(:pending) }

  describe "permissions test" do
    as_a :admin do
      describe "#new" do
        it "renders the full admin menu and new page" do
          get :new
          @response.body.must_include "Environment variables"
          @response.body.must_include "Users Report"
          @response.body.must_include "Reports"
          @response.body.must_include "Deploys CSV Report"
        end
      end
    end

    as_a :viewer do
      describe "#new" do
        it "renders the limited admin menu and limited new page" do
          get :new
          @response.body.wont_include "/admin/users"
          @response.body.must_include "Users Report"
          @response.body.must_include "Reports"
          @response.body.must_include "Deploys CSV Report"
        end
      end
    end
  end

  as_a :viewer do
    describe "#index" do
      describe "as html with exports" do
        it "renders the table of each status type" do
          create_exports
          get :index, params: {format: :html}
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
          get :index, params: {format: :html}
          assert_template :index
          @response.body.must_include "No current CSV Reports was found!"
        end
      end

      describe "as JSON with exports" do
        it "renders json" do
          create_exports
          get :index, params: {format: :json}
          @response.media_type.must_equal "application/json"
          @response.body.must_include CsvExport.all.to_json
        end
      end

      describe "as JSON without exports" do
        it "renders json" do
          CsvExport.delete_all
          get :index, params: {format: :json}
          @response.media_type.must_equal "application/json"
        end
      end
    end

    describe "#new" do
      describe "as html" do
        before do
          # clone a project to test it appears in the UI
          p = projects(:test).dup
          p.name = "Other Project"
          p.permalink = "other"
          p.save!(validate: false)
        end

        describe "empty type (Deploys)" do
          it "renders deploy form with deleted_projects" do
            Project.last.update_attribute(:deleted_at, Time.now)
            get :new
            assert_select "h1", "Request Deploys Report"
            @response.body.must_include ">Foo</option>"
            @response.body.must_include ">(deleted) Other Project</option>"
          end
        end

        describe "users type" do
          it "renders form options" do
            get :new, params: {type: :users}
            assert_select "h1", "User Permission Reports"
            @response.body.must_include ">Foo</option>"
            @response.body.must_include ">Other Project</option>"
            @response.body.must_include ">Viewer</option>"
            @response.body.must_include ">Super Admin</option>"
          end
        end

        describe "deploy_group_usage type" do
          it "renders form options" do
            get :new, params: {type: :deploy_group_usage}
            assert_select "h1", "Deploy Group Usage Report"
            @response.body.must_include "Download Deploy Group Usage Report"
          end
        end
      end

      describe "as csv" do
        describe "no type" do
          it "responds with not found" do
            get :new, params: {format: :csv}
            response.body.must_equal "not found"
          end
        end

        describe "deploy_group_usage type" do
          it "returns csv" do
            get :new, params: {format: :csv, type: "deploy_group_usage"}
            assert_response :success
          end
        end

        describe "users type" do
          before { users(:super_admin).soft_delete! }
          let(:expected) do
            {inherited: false, deleted: false, project_id: nil, user_id: nil}
          end

          it "returns csv with default options" do
            csv_test({}, expected)
          end

          it "returns csv with inherited option" do
            expected[:inherited] = true
            csv_test({inherited: "true"}, expected)
          end

          it "returns csv with specific project option" do
            expected[:inherited] = true
            expected[:project_id] = Project.first.id
            csv_test({project_id: Project.first.id}, expected)
          end

          it "returns csv with deleted option" do
            expected[:deleted] = true
            csv_test({deleted: "true"}, expected)
          end

          it "returns csv with specific user option and user is deleted" do
            expected[:inherited] = true
            expected[:user_id] = users(:super_admin).id
            csv_test({user_id: users(:super_admin).id}, expected)
          end

          it "returns csv with multiple options" do
            expected[:inherited] = true
            expected[:deleted] = true
            csv_test({inherited: "true", deleted: "true"}, expected)
          end

          def csv_test(options, expected)
            options = options.merge(format: :csv, type: "users")
            get :new, params: options
            assert_response :success
            CSV.parse(response.body).pop.pop.must_equal expected.to_json
          end
        end
      end
    end

    describe "#show" do
      def self.show_test(state)
        describe state do
          before { export.update_attribute('status', state) }

          describe "as html" do
            it "renders html" do
              get :show, params: {id: export.id, format: :html}
              assert_template :show
              @response.body.must_include show_expected_html(state)
            end
          end

          describe "as json" do
            it "renders json" do
              get :show, params: {id: export.id, format: :json}
              @response.media_type.must_equal "application/json"
              @response.body.must_equal export.reload.to_json
            end
          end

          describe "as csv with no file" do
            before do
              export.delete_file
              get :show, params: {id: export.id, format: :csv}
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
                CsvExportJob.new(export).perform
                export.update_attribute("status", state)
              end

              after { cleanup_files }

              it "receives file" do
                get :show, params: {id: export.id, format: 'csv'}
                @response.media_type.must_equal "text/csv"
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
              get :show, params: {id: -9999, format: :html}
            end
          end
        end

        describe "as json" do
          it "returns not found" do
            get :show, params: {id: -9999, format: :json}
            @response.media_type.must_equal "application/json"
            @response.body.must_include "not found"
            assert_response 404
          end
        end

        describe "as csv" do
          it "returns not found" do
            get :show, params: {id: -9999, format: :csv}
            @response.media_type.must_equal "text/csv"
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
          post :create, params: filter
        end
        assert_redirected_to CsvExport.last
        csv_filter = CsvExport.last.filters
        csv_filter.keys.must_include "deploys.created_at"
        csv_filter.keys.must_include "stages.production"
        csv_filter.keys.must_include "jobs.status"
        csv_filter.keys.must_include "stages.project_id"
        start_date = Time.parse(filter[:start_date])
        end_date = Time.parse(filter[:end_date] + "T23:59:59Z")
        csv_filter["deploys.created_at"].must_equal start_date..end_date
        csv_filter["stages.production"].must_equal true
        csv_filter["jobs.status"].must_equal "succeeded"
        csv_filter["stages.project_id"].must_equal projects(:test).id
      end

      def self.it_filters_production(prod, groups)
        it "with production filter #{prod == "Yes"} and DeployGroup enabled #{groups} creates correct filter" do
          DeployGroup.stubs(:enabled?).returns(groups)
          post :create, params: {production: prod}
          csv_filter = CsvExport.last.filters
          csv_filter[groups ? "environments.production" : "stages.production"].must_equal prod == "Yes"
        end
      end

      it_filters_production "Yes", true
      it_filters_production "Yes", false
      it_filters_production "No", true
      it_filters_production "No", false

      it "with production blank filter does not have stages.production filter" do
        post :create, params: {production: ""}
        csv_filter = CsvExport.last.filters
        refute csv_filter.key?("stages.production")
      end

      it "raises for invalid params" do
        create_fail_test(ArgumentError, start_date: '2000-13-13')
        create_fail_test(ArgumentError, end_date: '2015-13-31')
        create_fail_test("Invalid production filter foo", production: 'foo')
        create_fail_test("Invalid status filter foo", status: 'foo')
        create_fail_test("Invalid project id foo", project: "foo")
      end

      it "with filters bypassed" do
        post :create, params: {bypassed: "true"}
        CsvExport.last.filters.must_equal("deploys.buddy_id" => nil, "stages.no_code_deployed" => false)
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
    assert_raise message do
      post :create, params: filter
    end
  end
end
