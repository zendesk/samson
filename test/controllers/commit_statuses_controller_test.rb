require_relative '../test_helper'

describe CommitStatusesController do
  as_a_viewer do
    unauthorized :get, :show, project_id: :foo, id: 'test/test'
  end

  as_a_deployer do
    describe 'a GET to #show' do
      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: 123123, id: 'test/test'
        end
      end

      describe 'valid' do
        let(:commit_status_data) {
          {
            status: 'pending',
            status_list: [{ status: 'pending', description: 'the Travis build is still running' }]
          }
        }
        setup do
          CommitStatus.stubs(new: stub(commit_status_data))
          get :show, project_id: projects(:test), id: 'test/test'
        end

        it 'responds ok' do
          response.status.must_equal(200)
        end

        it 'responds with the status' do
          response.body.must_equal(JSON.dump(commit_status_data))
        end
      end
    end
  end

  as_a_viewer_project_deployer do
    describe 'a GET to #show' do
      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, project_id: 123123, id: 'test/test'
        end
      end

      describe 'valid' do
        let(:commit_status_data) {
          {
            status: 'pending',
            status_list: [{ status: 'pending', description: 'the Travis build is still running' }]
          }
        }
        setup do
          CommitStatus.stubs(new: stub(commit_status_data))
          get :show, project_id: projects(:test), id: 'test/test'
        end

        it 'responds ok' do
          response.status.must_equal(200)
        end

        it 'responds with the status' do
          response.body.must_equal(JSON.dump(commit_status_data))
        end
      end
    end
  end
end
