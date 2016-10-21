# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe LocksController do
  def create_lock(resource = nil, options = {})
    params = {resource_id: resource&.id.to_s, resource_type: resource&.class&.name.to_s, description: 'DESC'}
    params.merge!(options)
    post :create, params: {lock: params}
  end

  let(:stage) { stages(:test_staging) }
  let(:environment) { environments(:production) }
  let(:lock) { stage.create_lock! user: users(:deployer) }
  let(:global_lock) { Lock.create! user: users(:deployer) }

  before { request.headers['HTTP_REFERER'] = '/back' }

  describe "#for_stage_lock?" do
    it "raises on unsupported action" do
      @controller.stubs(action_name: 'show')
      assert_raises RuntimeError do
        @controller.send(:for_stage_lock?)
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

    it 'is unauthorized when doing a post to create a stage lock' do
      create_lock stage
      assert_response :unauthorized
    end

    it 'is unauthorized when doing a delete to destroy a stage lock' do
      delete :destroy, params: {id: lock.id}
      assert_response :unauthorized
    end

    it 'is unauthorized when doing a delete to destroy a global lock' do
      delete :destroy, params: {id: global_lock.id}
      assert_response :unauthorized
    end
  end

  as_a_project_deployer do
    unauthorized :post, :create

    it 'is not authorized to create a global lock' do
      create_lock
      assert_response :unauthorized
    end

    it 'is not authorized to create an environment lock' do
      create_lock environment
      assert_response :unauthorized
    end

    describe '#create' do
      before { travel_to Time.now }
      after { travel_back }

      it 'creates a stage lock' do
        create_lock stage, delete_in: 3600
        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        lock = stage.lock
        lock.warning?.must_equal(false)
        lock.description.must_equal 'DESC'
        lock.delete_at.must_equal(Time.now + 3600)
      end

      it 'creates a stage warning' do
        create_lock stage, warning: true
        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        lock = stage.lock
        lock.warning?.must_equal(true)
        lock.description.must_equal 'DESC'
      end
    end

    describe '#destroy' do
      it 'destroys a stage lock' do
        lock = stage.create_lock!(user: users(:deployer))
        delete :destroy, params: {id: lock.id}

        assert_redirected_to '/back'
        assert flash[:notice]

        stage.reload

        Lock.count.must_equal 0
      end
    end
  end

  as_a_admin do
    describe '#create' do
      it 'creates a global lock' do
        create_lock
        assert_redirected_to '/back'
        assert flash[:notice]

        lock = Lock.global.first
        lock.description.must_equal 'DESC'
      end

      it 'creates an environment lock' do
        create_lock environment
        assert_redirected_to '/back'
        assert flash[:notice]

        lock = environment.lock
        lock.description.must_equal 'DESC'
      end
    end

    describe '#destroy' do
      it 'destroys a global lock' do
        delete :destroy, params: {id: global_lock.id}

        assert_redirected_to '/back'
        assert flash[:notice]

        Lock.count.must_equal 0
      end
    end
  end
end
