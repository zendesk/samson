require_relative '../test_helper'

describe ProjectsController do
  setup do
    request.env['warden'].set_user(users(:admin))
  end

  describe "a GET to #index" do
    setup do
      get :index
    end

    it "renders a template" do
      assert_template :index
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
        let(:params) { { :project => { :name => "Hello", :repository_url => "git://foo.com/bar" } } }

        it "redirects to root url" do
          assert_redirected_to root_path
        end

        it "creates a new project" do
          Project.where(:name => "Hello").first.wont_be_nil
        end
      end

      describe "with invalid parameters" do
        let(:params) { { :project => { :name => "" } } }

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
    let(:project) { projects(:test) }

    describe "as an admin" do
      setup do
        delete :destroy, :id => project.id
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
    let(:project) { projects(:test) }

    describe "as an admin" do
      setup do
        put :update, params.merge(:id => project.id)
      end

      describe "with valid parameters" do
        let(:params) { { :project => { :name => "Hi-yo" } } }

        it "redirects to root url" do
          assert_redirected_to root_path
        end

        it "creates a new project" do
          Project.where(:name => "Hi-yo").first.wont_be_nil
        end
      end

      describe "with invalid parameters" do
        let(:params) { { :project => { :name => "" } } }

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
        put :update, :id => project.id
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
    let(:project) { projects(:test) }

    describe "as an admin" do
      setup do
        get :edit, :id => project.id
      end

      it "renders a template" do
        assert_template :edit
      end
    end

    describe "non-existant" do
      setup do
        project.soft_delete!
        get :edit, :id => project.id
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
    let(:project) { projects(:test) }

    as_a_deployer do
      setup do
        get :show, :id => project.id
      end

      it "renders a template" do
        assert_template :show
      end
    end

    describe "non-existant" do
      setup do
        project.soft_delete!
        get :edit, :id => project.id
      end

      it "sets the flash error" do
        request.flash[:error].wont_be_nil
      end

      it "redirects to root url" do
        assert_redirected_to root_path
      end
    end

    as_a_viewer do
      unauthorized :get, :show, id: 1
    end
  end
end
