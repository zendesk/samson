require_relative '../test_helper'

describe LocksController do
  let(:stage) { stages(:test_staging) }
  let(:lock) { stage.create_lock! user: users(:deployer) }
  let(:global_lock) { Lock.create! user: users(:deployer) }

  before { request.headers['HTTP_REFERER'] = '/back' }

  as_a_viewer do
    unauthorized :post, :create

    it('responds with unauthorized when doing a post to create a local lock') do
      post :create, lock: {stage_id: stage.id}
      @unauthorized.must_equal true, "Request was not marked unauthorized"
    end

    it('is unauthorized when doing a delete to destroy a local lock') do
      delete :destroy, id: lock.id
      @unauthorized.must_equal true, "Request was not marked unauthorized"
    end

    it('is unauthorized when doing a delete to destroy a global lock') do
      delete :destroy, id: global_lock.id
    end
  end

  as_a_deployer do
    unauthorized :post, :create

    it("responds with unauthorized when doing a post to create a global lock") do
      post :create, lock: {stage_id: '', description: "DESC"}
      @unauthorized.must_equal true, "Request was not marked unauthorized"
    end

    describe 'POST to #create' do
      it "creates a lock" do
        post :create, lock: {stage_id: stage.id, description: "DESC"}
        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(false)
        stage.locked?.must_equal(true)
        stage.lock.description.must_equal "DESC"
      end

      it "creates a warning" do
        post :create, lock: {stage_id: stage.id, description: "DESC", warning: true}
        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(true)
        stage.locked?.must_equal(false)
        stage.lock.description.must_equal "DESC"
      end
    end

    describe 'DELETE to #destroy' do
      it "destroys the lock" do
        lock = stage.create_lock!(user: users(:deployer))
        delete :destroy, id: lock.id

        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.locked?.must_equal(false)
        Lock.count.must_equal 0
      end
    end
  end

  as_a_admin do
    describe 'POST to #create' do
      it "creates a global lock" do
        post :create, lock: {stage_id: '', description: "DESC"}
        assert_redirected_to "/back"
        assert flash[:notice]

        lock = Lock.global.first
        lock.description.must_equal "DESC"
      end
    end

    describe 'DELETE to #destroy' do
      it "destroys a global lock" do
        delete :destroy, id: global_lock.id

        assert_redirected_to "/back"
        assert flash[:notice]

        Lock.count.must_equal 0
      end
    end
  end

  as_a_viewer_project_deployer do
    unauthorized :post, :create

    it("responds with unauthorized when doing a post to create a global lock") { post :create, id: global_lock.id }

    describe 'POST to #create' do
      it "creates a lock" do
        post :create, lock: {stage_id: stage.id, description: "DESC"}
        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(false)
        stage.locked?.must_equal(true)
        stage.lock.description.must_equal "DESC"
      end

      it "creates a warning" do
        post :create, lock: {stage_id: stage.id, description: "DESC", warning: true}
        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.warning?.must_equal(true)
        stage.locked?.must_equal(false)
        stage.lock.description.must_equal "DESC"
      end
    end

    describe 'DELETE to #destroy' do
      it "destroys the lock" do
        lock = stage.create_lock!(user: users(:deployer))
        delete :destroy, id: lock.id

        assert_redirected_to "/back"
        assert flash[:notice]

        stage.reload

        stage.locked?.must_equal(false)
        Lock.count.must_equal 0
      end
    end
  end
end
