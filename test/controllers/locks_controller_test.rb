require_relative '../test_helper'

SingleCov.covered!

describe LocksController do
  let(:stage) { stages(:test_staging) }
  let(:lock) { stage.create_lock! user: users(:deployer) }
  let(:global_lock) { Lock.create! user: users(:deployer) }

  before { request.headers['HTTP_REFERER'] = '/back' }

  describe "#for_global_lock?" do
    it "raises on unsupported action" do
      @controller.stubs(action_name: 'show')
      assert_raises RuntimeError do
        @controller.send(:for_global_lock?)
      end
    end
  end

  describe "#require_project" do
    it "raises on unsupported action" do
      @controller.stubs(action_name: 'show')
      assert_raises RuntimeError do
        @controller.send(:require_project)
      end
    end
  end

  as_a_viewer do
    unauthorized :post, :create

    it 'is unauthorized when doing a post to create a local lock' do
      post :create, lock: {stage_id: stage.id}
      assert_unauthorized
    end

    it 'is unauthorized when doing a delete to destroy a local lock' do
      delete :destroy, id: lock.id
      assert_unauthorized
    end

    it 'is unauthorized when doing a delete to destroy a global lock' do
      delete :destroy, id: global_lock.id
      assert_unauthorized
    end
  end

  as_a_project_deployer do
    unauthorized :post, :create

    it 'responds with unauthorized when doing a post to create a global lock' do
      post :create, lock: {stage_id: '', description: 'DESC'}
      assert_unauthorized
    end

    describe 'POST to #create' do
      before { travel_to Time.now }
      after { travel_back }

      it 'creates a lock' do
        post :create, lock: {stage_id: stage.id, description: 'DESC', delete_in: 3600 }
        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(false)
        stage.locked?.must_equal(true)
        stage.lock.description.must_equal 'DESC'
        stage.lock.delete_at.must_equal(Time.now + 3600)
      end

      it 'creates a warning' do
        post :create, lock: {stage_id: stage.id, description: 'DESC', warning: true}
        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(true)
        stage.locked?.must_equal(false)
        stage.lock.description.must_equal 'DESC'
      end
    end

    describe 'DELETE to #destroy' do
      it 'destroys the lock' do
        lock = stage.create_lock!(user: users(:deployer))
        delete :destroy, id: lock.id

        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        stage.locked?.must_equal(false)
        Lock.count.must_equal 0
      end
    end
  end

  as_a_admin do
    describe 'POST to #create' do
      it 'creates a global lock' do
        post :create, lock: {stage_id: '', description: 'DESC'}
        assert_redirected_to '/back'
        assert flash[:notice]

        lock = Lock.global.first
        lock.description.must_equal 'DESC'
      end
    end

    describe 'DELETE to #destroy' do
      it 'destroys a global lock' do
        delete :destroy, id: global_lock.id

        assert_redirected_to '/back'
        assert flash[:notice]

        Lock.count.must_equal 0
      end
    end
  end
end
