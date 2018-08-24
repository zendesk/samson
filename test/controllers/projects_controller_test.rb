# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 3

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

  as_a_viewer do
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

      it "can search" do
        Project.create!(name: "a", repository_url: "a")
        get :index, params: {search: {query: "o"}}
        assigns(:projects).map(&:name).must_equal ["Foo"]
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
          project = JSON.parse(response.body)
          project['name'].must_equal 'Foo'
          project['repository_path'].must_equal 'bar/foo'
          refute project.key?('deleted_at')
          refute project.key?('token')
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

    describe "#find_via_repository_url" do
      it "is json" do
        get :find_via_repository_url, params: {url: project.repository_url}
        assert_response :success
        project = JSON.parse(response.body).first
        project['name'].must_equal 'Foo'
        project['repository_path'].must_equal 'bar/foo'
      end

      it "not found response with unknown URL" do
        get :find_via_repository_url, params: {url: "xyz"}
        assert_response :not_found
      end
    end
  end

  as_a_deployer do
    unauthorized :put, :update, id: :foo
    unauthorized :delete, :destroy, id: :foo
  end

  as_a_project_admin do
    unauthorized :get, :new
    unauthorized :post, :create

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
        end
      end

      it "sends deletion notification" do
        delete :destroy, params: {id: project.to_param}
        mail = ActionMailer::Base.deliveries.last
        mail.subject.include?("Samson Project Deleted")
        mail.subject.include?(project.name)
      end

      it "does not fail when validations fail" do
        assert_difference 'Project.count', -1 do
          project.update_column(:name, "")
          delete :destroy, params: {id: project.to_param}
        end
      end
    end
  end

  as_an_admin do
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
      before do
        post :create, params: params
      end

      describe "with valid parameters" do
        let(:params) do
          {
            project: {
              name: "Hello",
              repository_url: "git://foo.com/bar"
            }
          }
        end
        let(:project) { Project.where(name: "Hello").first }

        it "redirects to the new project's page" do
          assert_redirected_to project_path(project)
        end

        it "creates a new project" do
          project.wont_be_nil
          project.stages.must_be_empty
        end

        it "notifies about creation" do
          mail = ActionMailer::Base.deliveries.last
          mail.subject.include?("Samson Project Created")
          mail.subject.include?(project.name)
        end
      end

      describe "with invalid parameters" do
        let(:params) { {project: {name: ""}} }

        it "renders new template" do
          assert_template :new
        end
      end
    end
  end
end
