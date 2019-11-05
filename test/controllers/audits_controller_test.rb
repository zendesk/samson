# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AuditsController do
  def create_audit(user)
    Audited.audit_class.as_user(user) do
      stage.update(name: "Fooo #{rand(9999999)}")
    end
  end

  let(:stage) { stages(:test_staging) }

  as_a :viewer do
    describe "#index" do
      before { create_audit user }

      it "renders" do
        get :index, params: {search: {auditable_id: stage.id, auditable_type: stage.class.name}}
        assert_template :index
      end

      it "renders with unfound user" do
        create_audit(User.new { |u| u.id = 1211212 })
        get :index, params: {search: {auditable_id: stage.id, auditable_type: stage.class.name}}
        assert_template :index
      end

      it "renders with deleted item" do
        stage.delete
        get :index, params: {search: {auditable_id: stage.id, auditable_type: stage.class.name}}
        assert_template :index
      end

      it "renders with removed class" do
        stage.audits.last.update_column(:auditable_type, 'Whooops')
        get :index, params: {search: {auditable_id: stage.id, auditable_type: 'Whooops'}}
        assert_template :index
      end

      it "does not N+1" do
        20.times { create_audit user }
        assert_sql_queries 8 do
          get :index
          assert_template :index
          assigns(:audits).size.must_equal 21
        end
      end
    end

    describe "#show" do
      before { create_audit user }

      it "renders" do
        get :show, params: {id: Audited::Audit.last.id}
        assert_template :show
      end
    end
  end
end
