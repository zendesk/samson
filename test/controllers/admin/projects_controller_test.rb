# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Admin::ProjectsController do
  let(:project) { projects(:test) }

  before do
    Project.any_instance.stubs(:clone_repository).returns(true)
    Project.any_instance.stubs(:valid_repository_url).returns(true)
  end

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :delete, :destroy, id: :foo
  end

  as_a_project_admin do
    unauthorized :get, :index
    unauthorized :delete, :destroy, id: :foo
  end

  as_a_admin do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
        assigns[:projects].must_equal [projects(:test)]
      end

      it "searches" do
        get :index, params: {search: {query: 'x'}}
        assert_template :index
        assigns[:projects].must_equal []
      end
    end

    describe "#destroy" do
      before do
        delete :destroy, params: {id: project.to_param}
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

      it "notifies about deletion" do
        mail = ActionMailer::Base.deliveries.last
        mail.subject.include?("Samson Project Deleted")
        mail.subject.include?(project.name)
      end
    end
  end
end
