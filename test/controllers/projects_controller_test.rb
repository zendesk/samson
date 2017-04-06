# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ProjectsController do
  let(:project) { projects(:test) }

  before do
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:valid_repository_url).returns(true)
  end

  describe "#index" do
    as_a_viewer do
      it "renders" do
        get :index
        assert_template :index
      end
    end

    as_a_deployer do
      it "renders" do
        get :index
        assert_template :index
      end
    end

    as_a_admin do
      it "renders" do
        get :index
        assert_template :index
      end

      it "assigns the user's starred projects to @projects" do
        starred_project = Project.create!(name: "a", repository_url: "a")
        users(:admin).stars.create!(project: starred_project)

        get :index

        assert_equal [starred_project], assigns(:projects)
      end

      it "assigns all projects to @projects if the user has no starred projects" do
        get :index

        assert_equal [projects(:test)], assigns(:projects)
      end

      it "responds to json requests" do
        get :index, params: {format: 'json'}
        result = JSON.parse(response.body)
        result['projects'].map(&:symbolize_keys!).map { |obj| obj[:name] }.must_equal ['Foo']
      end

      it "responds to CSV requests" do
        get :index, params: { format: 'csv' }
        csv = CSV.new(response.body, headers: true)
        all_projects = Project.order(:id).to_a

        csv.each_with_index do |row, idx|
          %w[Id Name Url].each do |attr|
            row.headers.must_include attr
          end
          row['Id'].must_equal all_projects[idx].id.to_s
        end
      end

      it 'renders starred projects first for json' do
        starred_project1 = Project.create!(name: 'Z', repository_url: 'Z')
        starred_project2 = Project.create!(name: 'A', repository_url: 'A')
        users(:admin).stars.create!(project: starred_project1)
        users(:admin).stars.create!(project: starred_project2)

        get :index, params: {format: 'json'}
        result = JSON.parse(response.body)
        result['projects'].map { |obj| obj['name'] }.must_equal ['A', 'Z', 'Foo']
      end
    end
  end

  describe "#new" do
    as_a_viewer do
      unauthorized :get, :new
    end

    as_a_deployer do
      unauthorized :get, :new
    end

    as_a_admin do
      it "renders" do
        get :new
        assert_template :new
      end

      it "renders with no environments" do
        DeployGroup.destroy_all
        Environment.destroy_all
        get :new
        assert_template :new
      end
    end

    as_a_project_admin do
      unauthorized :get, :new
    end
  end

  describe "#create" do
    as_a_viewer do
      unauthorized :post, :create
    end

    as_a_deployer do
      unauthorized :post, :create
    end

    as_a_admin do
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
        let(:params) { { project: { name: "" } } }

        it "renders new template" do
          assert_template :new
        end
      end
    end

    as_a_project_admin do
      unauthorized :post, :create
    end
  end

  describe "#update" do
    as_a_viewer do
      unauthorized :put, :update, id: :foo
    end

    as_a_deployer do
      unauthorized :put, :update, id: :foo
    end

    as_a_admin do
      it "does not find soft deleted" do
        project.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          put :update, params: {id: project.to_param}
        end
      end

      describe "common" do
        before do
          put :update, params: params.merge(id: project.to_param)
        end

        describe "with valid parameters" do
          let(:params) { { project: { name: "Hi-yo" } } }

          it "redirects to root url" do
            assert_redirected_to project_path(project.reload)
          end

          it "creates a new project" do
            Project.where(name: "Hi-yo").first.wont_be_nil
          end
        end

        describe "with invalid parameters" do
          let(:params) { { project: { name: "" } } }

          it "renders edit template" do
            assert_template :edit
          end
        end
      end
    end

    as_a_project_admin do
      it "does not find soft deleted" do
        project.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          put :update, params: {id: project.to_param}
        end
      end

      describe "common" do
        before do
          put :update, params: params.merge(id: project.to_param)
        end

        describe "with valid parameters" do
          let(:params) { { project: { name: "Hi-yo" } } }

          it "redirects to root url" do
            assert_redirected_to project_path(project.reload)
          end

          it "creates a new project" do
            Project.where(name: "Hi-yo").first.wont_be_nil
          end
        end

        describe "with invalid parameters" do
          let(:params) { { project: { name: "" } } }

          it "renders edit template" do
            assert_template :edit
          end
        end
      end
    end
  end

  describe "#edit" do
    as_a_viewer do
      unauthorized :get, :edit, id: :foo
    end

    as_a_deployer do
      unauthorized :get, :edit, id: :foo
    end

    as_a_admin do
      it "renders" do
        get :edit, params: {id: project.to_param}
        assert_template :edit
      end

      it "does not find soft deleted" do
        project.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {id: project.to_param}
        end
      end
    end

    as_a_project_admin do
      it "renders" do
        get :edit, params: {id: project.to_param}
        assert_template :edit
      end

      it "does not find soft deleted" do
        project.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {id: project.to_param}
        end
      end
    end
  end

  describe "#show" do
    as_a_viewer do
      describe "as HTML" do
        it "does not redirect to the deploys page" do
          get :show, params: {id: project.to_param}
          assert_response :success
        end
      end

      describe "as JSON" do
        it "is json and does not include :token" do
          get :show, params: {id: project.permalink, format: :json}
          assert_response :success
          result = JSON.parse(response.body)
          result.keys.wont_include('token')
        end
      end
    end

    as_a_deployer do
      it "renders" do
        get :show, params: {id: project.to_param}
        assert_template :show
      end

      it "does not find soft deleted" do
        project.soft_delete!
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {id: project.to_param}
        end
      end
    end
  end

  describe '#deploy_group_versions' do
    let(:deploy) { deploys(:succeeded_production_test) }

    as_a_viewer do
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
end
