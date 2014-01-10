require_relative '../test_helper'

describe StagesController do
  as_a_deployer do

    describe 'GET to :show' do
      subject { stages(:test_staging) }

      describe 'valid' do
        before do
          get :show, :project_id => subject.project_id,
            :id => subject.id
        end

        it 'renders the template' do
          assert_template :show
        end
      end

      describe 'invalid project' do
        before do
          get :show, :project_id => 123123,
            :id => subject.id
        end

        it 'renders the template' do
          assert_template :show
        end
      end

      describe 'invalid stage' do
        before do
          get :show, :project_id => 123123,
            :id => subject.id
        end

        it 'renders the template' do
          assert_template :show
        end
      end
    end

    unauthorized :get, :new, project_id: 1
    unauthorized :post, :create, project_id: 1
    unauthorized :get, :edit, project_id: 1, id: 1
    unauthorized :delete, :destroy, project_id: 1, id: 1
  end

  as_a_admin do
  end
end
