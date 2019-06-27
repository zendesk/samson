# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe "ResourceController Integration" do
  let(:described_class) { ResourceController }

  def assert_rendered_resource
    json.keys.must_equal [:project]
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  let(:project) { projects(:test) }

  as_a :admin do
    describe "#index" do
      describe "html" do
        it "renders" do
          get commands_url
          assert_response :success
          assigns(:commands).size.must_equal 2
        end

        it "renders with default" do
          Lock.create!(user: users(:admin), description: "foo")
          get locks_url(:json)
          assert_response :success
          assigns(:locks).size.must_equal 1
        end

        it "can define the page size" do
          get commands_url, params: {per_page: 1}
          assigns(:commands).size.must_equal 1
        end

        it "renders without pagination" do
          get project_stages_url(project_id: project), params: {per_page: 1}
          assigns(:stages).size.must_equal 3
        end
      end

      describe "json" do
        it "renders" do
          get commands_url(:json)
          assert_response :success
          json.keys.must_equal [:commands]
        end

        it "includes" do
          get deploys_url(:json), params: {includes: "job"} # TODO: covert deploys to actually use ResourceController
          assert_response :success
          json.keys.must_equal [:deploys, :jobs]
        end
      end

      describe "csv" do
        it "renders" do
          assert_sql_queries 2 do
            get commands_url(:csv)
          end
          assert_response :success
          csv = response.body.split("\n")
          csv.size.must_equal Command.count + 3 # header + count + url
          csv[0][0..50].must_equal "Id,Command,Created at,Updated at,Project"
          csv[-2].must_equal "-,count:,#{Command.count}"
          csv[-1].must_equal "-,url:,http://www.test-url.com/commands.csv"
        end

        it "removes paging limits" do
          get commands_url(:csv), params: {per_page: 1}
          assert_response :success
          csv = response.body.split("\n")
          csv.size.must_equal Command.count + 3 # header + count + url
        end

        it "renders empty" do
          assert_sql_queries 2 do
            get commands_url(:csv, search: {query: "nope"})
          end
          assert_response :success
          csv = response.body.split("\n")
          csv.size.must_equal 3 # header + url
          csv[0][0..50].must_equal "Empty"
          csv[-2].must_equal "-,count:,0"
          csv[-1].must_equal "-,url:,http://www.test-url.com/commands.csv?search%5Bquery%5D=nope"
        end
      end
    end

    describe "#new" do
      describe "html" do
        it "renders" do
          get new_project_url
          assert_response :success
        end

        it "can prefill the form" do
          get new_project_url(project: {name: "CustomName"})
          assert_response :success
          response.body.must_include 'value="CustomName"'
        end
      end

      describe "json" do
        it "refuses to render" do
          assert_raises ActionController::UnknownFormat do
            get new_project_url(:json)
          end
        end
      end
    end

    describe "#create" do
      before do
        Project.any_instance.stubs(:clone_repository).returns(true)
        Project.any_instance.stubs(:valid_repository_url).returns(true)
      end

      let(:project_params) { {name: "Hello", repository_url: "git://foo.com/bar"} }

      describe "html" do
        it "creates" do
          post projects_url, params: {project: project_params}
          assert_redirected_to Project.last
        end

        it "can redirect to new" do
          post projects_url, params: {project: project_params, commit: ResourceController::ADD_MORE}
          assert_redirected_to "/projects/new?#{{project: project_params}.to_query}"
        end

        it "fails to creates" do
          project_params[:name] = ""
          post projects_url, params: {project: project_params}
          assert_response :success
        end

        it "fails on missing param" do
          assert_raises ActionController::ParameterMissing do
            post projects_url
          end
        end

        it "fails on unpermitted param" do
          assert_raises ActionController::UnpermittedParameters do
            post projects_url, params: {project: {foo: "bar"}}
          end
        end
      end

      describe "json" do
        it "creates" do
          post projects_url(:json), params: {project: project_params}
          assert_response :created
          assert_rendered_resource
        end

        it "fails to creates" do
          project_params[:name] = ""
          post projects_url(:json), params: {project: project_params}
          assert_response :unprocessable_entity
          json.must_equal status: 422, error: {name: ["can't be blank"]}
        end

        it "fails on missing param" do
          post projects_url(:json)
          assert_response :bad_request
          json.must_equal status: 400, error: {project: ["is required"]}
        end

        it "fails on unpermitted param" do
          post projects_url(:json), params: {project: {foo: "bar"}}
          assert_response :bad_request
          json.must_equal status: 400, error: {foo: ["is not permitted"]}
        end
      end
    end

    describe "#show" do
      describe "html" do
        it "renders" do
          get project_url(project)
          assert_response :success
        end
      end

      describe "json" do
        it "renders" do
          get project_url(project, :json)
          assert_response :success
          assert_rendered_resource
        end

        it "includes" do
          get project_url(project, :json), params: {includes: "environment_variable_groups"}
          assert_response :success
          json.keys.must_equal [:project, :environment_variable_groups]
        end
      end
    end

    describe "#edit" do
      describe "html" do
        it "renders" do
          get edit_project_url(project)
          assert_response :success
        end
      end

      describe "json" do
        it "refuses to render" do
          assert_raises ActionController::UnknownFormat do
            get edit_project_url(project, :json)
          end
        end
      end
    end

    describe "#update" do
      let(:project_params) { {name: "Baz2", description: "Gah2"} }
      describe "html" do
        it "updates" do
          patch project_url(project), params: {project: project_params}
          assert_redirected_to project
        end

        it "can redirect to new" do
          patch project_url(project), params: {project: project_params, commit: ResourceController::ADD_MORE}
          assert_redirected_to "/projects/new?#{{project: project_params}.to_query}"
        end

        it "fails to update" do
          patch project_url(project), params: {project: {name: ""}}
          assert_response :success
        end
      end

      describe "json" do
        it "updates" do
          patch project_url(project, :json), params: {project: project_params}
          assert_response :success
          assert_rendered_resource
        end

        it "fails to update" do
          patch project_url(project, :json), params: {project: {name: ""}}
          json.must_equal status: 422, error: {name: ["can't be blank"]}
        end
      end
    end

    describe "#destroy" do
      let(:command) { commands(:global) }

      describe "html" do
        it "soft deletes" do
          delete project_url(project)
          assert_redirected_to projects_url
          refute Project.find_by_id(project.id)
          assert Project.with_deleted { Project.find_by_id(project.id) }
        end

        it "destroys when soft-delete is not available" do
          delete command_url(command)
          assert_redirected_to commands_url
          assert flash[:notice]
          refute Command.find_by_id(command.id)
        end

        it "shows errors when deletion fails" do
          StageCommand.create! command: command, stage: stages(:test_production)
          delete command_url(command)
          assert_redirected_to command_url(command)
          assert flash[:alert]
          assert Command.find_by_id(command.id)
        end
      end

      describe "json" do
        it "deletes" do
          delete project_url(project, :json)
          assert_response :success
          response.body.must_equal ""
        end

        it 'fails to delete' do
          StageCommand.create! command: command, stage: stages(:test_production)
          delete command_url(command, :json)
          json.must_equal status: 422, error: {base: ["Can only delete when unused."]}
          assert Command.find_by_id(command.id)
        end
      end
    end
  end
end
