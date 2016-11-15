# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe VersionsController do
  def create_version(user)
    PaperTrail.with_whodunnit_user(user) do
      PaperTrail.with_logging do
        stage.update_attribute(:name, 'Fooo')
      end
    end
  end

  let(:stage) { stages(:test_staging) }

  as_a_viewer do
    describe "#index" do
      before { create_version user }

      it "renders" do
        get :index, params: {item_id: stage.id, item_type: stage.class.name}
        assert_template :index
      end

      it "renders with jenkins job name" do
        stage.update_attribute(:jenkins_job_names, 'jenkins-job-1')
        stage.update_attribute(:jenkins_job_names, 'jenkins-job-2')
        get :index, params: {item_id: stage.id, item_type: stage.class.name}
        assert_template :index
        assert_select 'p', text: /jenkins-job-1/
      end

      it "renders with unfound user" do
        create_version(User.new { |u| u.id = 1211212 })
        get :index, params: {item_id: stage.id, item_type: stage.class.name}
        assert_template :index
      end

      it "renders with deleted item" do
        stage.delete
        get :index, params: {item_id: stage.id, item_type: stage.class.name}
        assert_template :index
      end

      it "renders with removed class" do
        stage.versions.last.update_column(:item_type, 'Whooops')
        get :index, params: {item_id: stage.id, item_type: 'Whooops'}
        assert_template :index
      end
    end
  end
end
