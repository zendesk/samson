# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProjectsController do
  def fields_disabled?
    assert_select 'fieldset' do |fs|
      return fs.attr('disabled').present?
    end
  end

  let(:project) { projects(:test) }

  before do
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:valid_repository_url).returns(true)
    projects(:other).delete
  end

  as_a :viewer do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
      end

      it "orders user's starred projects to the front" do
        starred_project = Project.create!(name: "a", repository_url: "a")
        user.stars.create!(project: starred_project)

        get :index

        assigns(:projects).map(&:name).must_equal [starred_project.name, "Foo"]
      end

      it "renders nav" do
        get :index, params: {partial: "nav"}
        assert_template "projects/_nav"
        response.body.wont_include "<html"
      end

      describe "search" do
        it "can search via query" do
          get :index, params: {search: {query: "foo"}}
          assigns(:projects).map(&:name).must_equal ["Foo"]
        end

        it "can combine query and url" do
          get :index, params: {search: {query: "foo", url: "git@example.com:bar/foo.git"}}
          assigns(:projects).map(&:name).must_equal ["Foo"]
        end

        describe "via url" do
          def validate_search_url(url, result)
            get :index, params: {search: {url: url}}
            assigns(:projects).map(&:name).must_equal result
          end

          before do
            Project.create!(name: "https_url", repository_url: "https://github.com/foo/bar.git")
          end

          it "renders with https and .git in url" do
            validate_search_url("https://github.com/foo/bar.git", ["https_url"])
          end

          it "renders with ssh in url" do
            validate_search_url("ssh://git@example.com:bar/foo.git", ["Foo"])
          end

          it "renders without .git in url" do
            validate_search_url("https://github.com/foo/bar", ["https_url"])
          end

          it "renders without .git and with @git in url" do
            validate_search_url("git@example.com/bar/foo", ["Foo"])
          end

          it "does not find when url does not match" do
            get :index, params: {search: {url: "https://github.com/test.git"}}
            assigns(:projects).map(&:name).must_be_empty
          end
        end
      end

      it "renders json" do
        get :index, params: {format: 'json'}
        result = JSON.parse(response.body)
        projects = result['projects']
        projects.length.must_equal 1
        project = projects.first
        project['name'].must_equal 'Foo'
        project['repository_path'].must_equal 'bar/foo'
        refute project.key?('deleted_at')
        refute project.key?('token')
      end

      it "returns the last deploy date in JSON" do
        get :index, params: {format: 'json'}
        result = JSON.parse(response.body)
        project = result['projects'].first
        project['last_deployed_at'].must_include '2014-01'
        project['last_deployed_by'].must_include '@example.com'
        project['last_deploy_url'].must_include 'www.test-url.com'
      end

      it "renders CSV" do
        get :index, params: {format: 'csv'}
        csv = CSV.new(response.body, headers: true)
        all_projects = Project.order(:id).to_a

        csv.each_with_index do |row, idx|
          %w[Id Name Url].each do |attr|
            row.headers.must_include attr
          end
          row['Id'].must_equal all_projects[idx].id.to_s
          row['Last Deploy At'].must_include '2014-01'
          row['Last Deploy By'].must_include '@example.com'
          row['Last Deploy URL'].must_include 'www.test-url.com'
        end
      end

      it 'renders starred projects first for json' do
        starred_project1 = Project.create!(name: 'Z', repository_url: 'Z')
        starred_project2 = Project.create!(name: 'A', repository_url: 'A')
        user.stars.create!(project: starred_project1)
        user.stars.create!(project: starred_project2)

        get :index, params: {format: 'json'}
        result = JSON.parse(response.body)
        result['projects'].map { |obj| obj['name'] }.must_equal ['A', 'Z', 'Foo']
      end
    end

    describe "#show" do
      describe "as HTML" do
        it "renders" do
          get :show, params: {id: project.to_param}
          assert_response :success
        end

        it "does not find soft deleted" do
          project.soft_delete!(validate: false)
          assert_raises ActiveRecord::RecordNotFound do
            get :show, params: {id: project.to_param}
          end
        end
      end

      describe "as JSON" do
        it "is json and does not include :token" do
          get :show, params: {id: project.permalink, format: :json}
          assert_response :success
          result = JSON.parse(response.body)
          result.keys.must_include "project"
          project = result["project"]
          project['name'].must_equal 'Foo'
          project['repository_path'].must_equal 'bar/foo'
          refute project.key?('deleted_at')
          refute project.key?('token')
        end

        it "renders with envionment_variable_groups if present" do
          get :show, params: {id: project.to_param, includes: "environment_variable_groups", format: :json}
          assert_response :success
          project = JSON.parse(response.body)
          project.keys.must_include "environment_variable_groups"
        end

        it "renders with environment_variables_with_scope if present" do
          get :show, params: {id: project.to_param, includes: "environment_variables_with_scope", format: :json}
          assert_response :success
          project = JSON.parse(response.body)
          project.keys.must_include "environment_variables_with_scope"
        end
      end
    end

    describe '#edit' do
      it 'renders with disabled fields' do
        get :edit, params: {id: project.to_param}
        assert_template :edit
        assert fields_disabled?
      end
    end

    describe '#deploy_group_versions' do
      let(:deploy) { deploys(:succeeded_production_test) }

      it 'renders' do
        get :deploy_group_versions, params: {id: project.to_param, format: 'json'}
        result = JSON.parse(response.body)
        result.keys.sort.must_equal DeployGroup.all.ids.map(&:to_s).sort
      end

      it 'renders a custom timestamp' do
        time = deploy.updated_at - 1.day
        old = Deploy.create!(
          stage: stages(:test_production),
          job: deploy.job,
          reference: "new",
          updated_at: time - 1.day,
          release: true,
          project: project
        )
        get :deploy_group_versions, params: {id: project.to_param, before: time.to_s}
        deploy_ids = JSON.parse(response.body).map { |_id, deploy| deploy['id'] }
        deploy_ids.include?(deploy.id).must_equal false
        deploy_ids.include?(old.id).must_equal true
      end
    end
  end

  as_a :deployer do
    unauthorized :put, :update, id: :foo
    unauthorized :delete, :destroy, id: :foo
  end

  as_a :project_admin do
    unauthorized :get, :new
    unauthorized :post, :create, project: {name: "foo"}

    describe "#edit" do
      with_env DOCKER_FEATURE: "1"
      it "renders" do
        get :edit, params: {id: project.to_param}
        assert_template :edit
        refute fields_disabled?
      end

      it "renders with docker fields" do
        with_env DOCKER_FORCE_EXTERNAL_BUILD: nil do
          get :edit, params: {id: project.to_param}
          assert_select 'select[id=project_docker_build_method]'
          assert_select 'input[id=project_docker_release_branch]'
          assert_select 'input[id=project_dockerfiles]'
        end
      end

      it "renders without docker fields" do
        with_env DOCKER_FORCE_EXTERNAL_BUILD: "1" do
          get :edit, params: {id: project.to_param}
          assert_select 'input[id=project_docker_release_branch]', count: 0
          assert_select 'select[id=project_docker_build_method]', count: 0
          assert_select 'input[id=project_dockerfiles]'
        end
      end

      it "does not find soft deleted" do
        project.soft_delete!(validate: false)
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {id: project.to_param}
        end
      end
    end

    describe "#update" do
      let(:params) { {id: project.to_param, project: {name: "Hi-yo"}} }

      it "updates" do
        put :update, params: params
        project.reload
        assert_redirected_to project_path(project)
        project.name.must_equal "Hi-yo"
      end

      it "does not update invalid" do
        params[:project][:name] = ""
        put :update, params: params
        assert_template :edit
      end

      it "does not find soft deleted" do
        project.soft_delete!(validate: false)
        assert_raises ActiveRecord::RecordNotFound do
          put :update, params: params
        end
      end
    end

    describe "#destroy" do
      it "removes the project" do
        assert_difference 'Project.count', -1 do
          delete :destroy, params: {id: project.to_param}

          assert_redirected_to projects_path
          request.flash[:notice].wont_be_nil

          refute ActionMailer::Base.deliveries.last
        end
      end

      it "sends deletion notification" do
        with_env PROJECT_DELETED_NOTIFY_ADDRESS: 'foo@bar.com' do
          delete :destroy, params: {id: project.to_param}
          mail = ActionMailer::Base.deliveries.last
          mail.subject.include?("Samson Project Deleted")
          mail.subject.include?(project.name)
        end
      end

      it "does not fail when validations fail" do
        assert_difference 'Project.count', -1 do
          project.update_column(:name, "")
          delete :destroy, params: {id: project.to_param}
        end
      end
    end
  end

  as_a :admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_template :new
      end

      it "renders without environments" do
        DeployGroup.destroy_all
        Environment.destroy_all
        get :new
        assert_template :new
      end
    end

    describe "#create" do
      let(:params) do
        {
          project: {
            name: "Hello",
            repository_url: "git://foo.com/bar"
          }
        }
      end

      it "redirects to the new project's page" do
        post :create, params: params
        project = Project.last
        assert_redirected_to project_path(project)
        refute ActionMailer::Base.deliveries.last
      end

      it "notifies about creation" do
        with_env PROJECT_CREATED_NOTIFY_ADDRESS: 'foo@bar.com' do
          post :create, params: params
          mail = ActionMailer::Base.deliveries.last
          mail.subject.include?("Samson Project Created")
          mail.subject.include?(project.name)
        end
      end

      describe "with invalid parameters" do
        before { params[:project][:name] = '' }

        it "renders new template" do
          post :create, params: params
          assert_template :new
        end
      end
    end
  end
end
