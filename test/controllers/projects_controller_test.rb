require_relative '../test_helper'

describe ProjectsController do
  let(:project) { projects(:test) }
  let(:user) { users(:admin) }

  setup do
    request.env['warden'].set_user(user)
  end

  describe "a GET to #index" do
    it "renders a template" do
      get :index
      assert_template :index
    end

    it "assigns the user's starred projects to @projects" do
      unstarred_project = projects(:test)
      starred_project = Project.create!(name: "a", repository_url: "a")

      user.stars.create!(project: starred_project)

      get :index

      assert_equal [starred_project], assigns(:projects)
    end

    it "assigns all projects to @projects if the user has no starred projects" do
      project = projects(:test)

      get :index

      assert_equal [project], assigns(:projects)
    end
  end

  describe "a GET to #new" do
    describe "as an admin" do
      setup do
        get :new
      end

      it "renders a template" do
        assert_template :new
      end
    end

    as_a_deployer do
      unauthorized :get, :new
    end
  end

  describe "a POST to #create" do
    describe "as an admin" do
      setup do
        post :create, params
      end

      describe "with valid parameters" do
        let(:params) { { project: { name: "Hello", repository_url: "git://foo.com/bar" } } }
        let(:project) { Project.where(name: "Hello").first }

        it "redirects to the new project's page" do
          assert_redirected_to project_path(project)
        end

        it "creates a new project" do
          project.wont_be_nil
        end

        it "notifies about creation" do
          ActionMailer::Base.deliveries.last.subject.include?("Samson Project Created")
          ActionMailer::Base.deliveries.last.subject.include?(project.name)
        end
      end

      describe "with invalid parameters" do
        let(:params) { { project: { name: "" } } }

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end

        it "renders new template" do
          assert_template :new
        end
      end

      describe "with no parameters" do
        let(:params) {{}}

        it "redirects to root url" do
          assert_redirected_to root_path
        end
      end
    end

    as_a_deployer do
      unauthorized :post, :create
    end
  end

  describe "a DELETE to #destroy" do
    describe "as an admin" do
      setup do
        delete :destroy, id: project.to_param
      end

      it "redirects to root url" do
        assert_redirected_to admin_projects_path
      end

      it "removes the project" do
        project.reload
        project.deleted_at.wont_be_nil
      end

      it "sets the flash" do
        request.flash[:notice].wont_be_nil
      end
    end

    as_a_deployer do
      unauthorized :delete, :destroy, id: 1
    end
  end

  describe "a PUT to #update" do
    describe "as an admin" do
      setup do
        put :update, params.merge(id: project.to_param)
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

        it "sets the flash error" do
          request.flash[:error].wont_be_nil
        end

        it "renders edit template" do
          assert_template :edit
        end
      end

      describe "with no parameters" do
        let(:params) {{}}

        it "redirects to root url" do
          assert_redirected_to root_path
        end
      end
    end

    describe "non-existant" do
      setup do
        project.soft_delete!
        put :update, id: project.to_param
      end

      it "sets the flash error" do
        request.flash[:error].wont_be_nil
      end

      it "redirects to root url" do
        assert_redirected_to root_path
      end
    end

    as_a_deployer do
      unauthorized :put, :update, id: 1
    end
  end

  describe "a GET to #edit" do
    describe "as an admin" do
      setup do
        get :edit, id: project.to_param
      end

      it "renders a template" do
        assert_template :edit
      end
    end

    describe "non-existant" do
      setup do
        project.soft_delete!
        get :edit, id: project.to_param
      end

      it "sets the flash error" do
        request.flash[:error].wont_be_nil
      end

      it "redirects to root url" do
        assert_redirected_to root_path
      end
    end

    as_a_deployer do
      unauthorized :get, :edit, id: 1
    end
  end

  describe "a GET to #show" do
    as_a_deployer do
      setup do
        get :show, id: project.to_param
      end

      it "renders a template" do
        assert_template :show
      end
    end

    describe "non-existant" do
      setup do
        project.soft_delete!
        get :edit, id: project.to_param
      end

      it "sets the flash error" do
        request.flash[:error].wont_be_nil
      end

      it "redirects to root url" do
        assert_redirected_to root_path
      end
    end

    as_a_viewer do
      setup do
        get :show, id: project.to_param
      end

      it "redirects to the deploys page" do
        assert_redirected_to project_deploys_path(project)
      end
    end
  end
end
