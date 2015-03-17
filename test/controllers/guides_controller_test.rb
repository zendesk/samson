require_relative '../test_helper'

describe GuidesController do
  let(:guide) { guides(:test) }

  describe "a POST to #create" do
    as_a_viewer do
      unauthorized :post, :create, project_id: 1
    end

    as_a_deployer do
      unauthorized :post, :create, project_id: 1
    end

    as_a_admin do
      setup do
        post :create, params
      end

      describe "with valid parameters" do
        let(:project) { projects(:test) }
        let(:guide) { Guide.where(body: "**Foo**").first }
        let(:params) { { guide: { body: "**Foo**" }, project_id: project.permalink } }

        it "redirects to the new guide" do
          assert_redirected_to project_guide_path(project)
        end

        it "creates a new guide" do
          guide.wont_be_nil
        end
      end
    end
  end

  describe "a PUT to #update" do
    as_a_viewer do
      unauthorized :put, :update, project_id: 1
    end

    as_a_deployer do
      unauthorized :put, :update, project_id: 1
    end

    as_a_admin do
      describe "common" do
        setup do
          put :update, params.merge(project_id: guide.project.to_param)
        end

        describe "with valid parameters" do
          let(:params) { { guide: { body: "Hi-yo" } } }

          it "redirects to guide" do
            assert_redirected_to project_guide_path(guide.project.reload)
          end

          it "creates a new guide" do
            Guide.where(body: "Hi-yo").first.wont_be_nil
          end
        end
      end
    end
  end

  describe "a GET to #edit" do
    as_a_viewer do
      unauthorized :get, :edit, project_id: 1
    end

    as_a_deployer do
      unauthorized :get, :edit, project_id: 1
    end

    as_a_admin do
      it "renders" do
        get :edit, project_id: guide.project.to_param
        assert_template :edit
      end
    end
  end

  describe "a GET to #show" do
    as_a_viewer do
      it "renders" do
        get :show, project_id: guide.project.to_param
        assert_template :show
      end
    end

    as_a_deployer do
      it "renders" do
        get :show, project_id: guide.project.to_param
        assert_template :show
      end
    end
  end
end
