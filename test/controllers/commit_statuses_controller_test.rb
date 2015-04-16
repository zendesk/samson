require_relative '../test_helper'

describe CommitStatusesController do
  as_a_viewer do
    it 'authorizes correctly' do
      unauthorized :get, :show, project_id: projects(:test).to_param, id: 'test/test'
    end
  end

  as_a_deployer do
    describe 'a GET to #show' do
      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: 123123, id: 'test/test'
        end
      end

      describe 'valid' do
        setup do
          CommitStatus.stubs(new: stub(status: 'pending', class: CommitStatus))
          get :show, project_id: projects(:test), id: 'test/test'
        end

        it 'responds ok' do
          response.status.must_equal(200)
        end

        it 'responds with the status' do
          response.body.must_equal(JSON.dump(status: 'pending'))
        end
      end
    end
  end
end
