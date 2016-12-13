# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SessionsController do
  describe "#new" do
    describe "when logged in" do
      before do
        request.env['warden'].set_user(users(:admin))
        get :new
      end

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end

    describe "when not logged in" do
      before do
        get :new
      end

      it "renders" do
        assert_template :new
      end
    end
  end

  describe "#github" do
    let(:env) { {} }
    let(:user) { users(:github_viewer) }
    let(:strategy) { stub(name: 'github') }
    let(:uid) { user.external_id[/\d/] }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: uid,
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        ),
        extra: Hashie::Mash.new(
          raw_info: Hashie::Mash.new(
            login: 'xyz'
          )
        )
      )
    end
    let(:role_id) { Role::VIEWER.id }

    before do
      GithubAuthorization.any_instance.stubs(role_id: role_id)

      @request.env.merge!(env)
      @request.env['omniauth.auth'] = auth_hash
      @request.env['omniauth.strategy'] = strategy

      post :github
    end

    it 'logs the user in' do
      old = user.last_login_at
      @controller.send(:current_user).must_equal(user)
      user.reload.last_login_at.must_be :>, old
    end

    it 'redirects to the root path' do
      assert_redirected_to root_path
    end

    describe 'with an origin' do
      let(:env) { { 'omniauth.origin' => '/hello' } }

      it 'redirects to /hello' do
        assert_redirected_to '/hello'
      end
    end

    describe 'without organization access' do
      let(:role_id) { nil }

      it 'is not allowed to view anything' do
        @controller.send(:current_user).must_be_nil
        assert_template :new
        request.flash[:error].wont_be_nil
      end
    end

    describe 'with invalid role' do
      let(:uid) { 123 } # force new user
      let(:role_id) { 1234 } # make new user invalid

      it 'does not log in' do
        assert flash[:error]
        @controller.send(:current_user).must_be_nil
        assert_redirected_to root_path
      end
    end
  end

  describe "#google" do
    let(:env) { {} }
    let(:user) { users(:viewer) }
    let(:strategy) { stub(name: 'google') }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: '4',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    before do
      @request.env.merge!(env)
      @request.env['omniauth.auth'] = auth_hash
      @request.env['omniauth.strategy'] = strategy
      user.update_column(:external_id, "#{strategy.name}-#{auth_hash.uid}")
    end

    describe 'without email restriction' do
      before do
        @controller.stubs(:restricted_email_domain).returns(nil)
        post :google
      end

      it 'logs the user in' do
        @controller.send(:current_user).must_equal(user)
      end

      it 'redirects to the root path' do
        assert_redirected_to root_path
      end

      describe 'with an origin' do
        let(:env) { { 'omniauth.origin' => '/hello' } }

        it 'redirects to /hello' do
          assert_redirected_to '/hello'
        end
      end
    end

    describe "with email restriction" do
      before do
        @controller.stubs(:restricted_email_domain).returns("@uniqlo.com")
        post :google
      end

      it 'does not log the user in' do
        @controller.send(:current_user).must_be_nil
      end

      it "renders" do
        assert_template :new
      end

      it "sets a flash error" do
        request.flash[:error].wont_be_nil
      end
    end
  end

  describe "#gitlab" do
    let(:env) { {} }
    let(:user) { users(:viewer) }
    let(:strategy) { stub(name: 'gitlab') }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: '4',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    before do
      @request.env.merge!(env)
      @request.env['omniauth.auth'] = auth_hash
      @request.env['omniauth.strategy'] = strategy
      user.update_column(:external_id, "#{strategy.name}-#{auth_hash.uid}")
    end

    describe 'without email restriction' do
      before do
        @controller.stubs(:restricted_email_domain).returns(nil)
        post :gitlab
      end

      it 'logs the user in' do
        @controller.send(:current_user).must_equal(user)
      end

      it 'redirects to the root path' do
        assert_redirected_to root_path
      end

      describe 'with an origin' do
        let(:env) { { 'omniauth.origin' => '/hello' } }

        it 'redirects to /hello' do
          assert_redirected_to '/hello'
        end
      end
    end

    describe "with email restriction" do
      before do
        @controller.stubs(:restricted_email_domain).returns("@uniqlo.com")
        post :gitlab
      end

      it 'does not log the user in' do
        @controller.send(:current_user).must_be_nil
      end

      it "renders" do
        assert_template :new
      end

      it "sets a flash error" do
        request.flash[:error].wont_be_nil
      end
    end
  end

  describe "#ldap" do
    let(:env) { {} }
    let(:user) { users(:viewer) }
    let(:strategy) { stub(name: 'ldap') }
    let(:auth_hash) do
      Hashie::Mash.new(
        uid: '4',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    before do
      @request.env.merge!(env)
      @request.env['omniauth.auth'] = auth_hash
      @request.env['omniauth.strategy'] = strategy
      user.update_column(:external_id, "#{strategy.name}-#{auth_hash.uid}")
    end

    describe 'without email restriction' do
      before do
        @controller.stubs(:restricted_email_domain).returns(nil)
        post :ldap
      end

      it 'logs the user in' do
        @controller.send(:current_user).must_equal(user)
      end

      it 'redirects to the root path' do
        assert_redirected_to root_path
      end

      describe 'with an origin' do
        let(:env) { { 'omniauth.origin' => '/hello' } }

        it 'redirects to /hello' do
          assert_redirected_to '/hello'
        end
      end
    end

    describe "with email restriction" do
      before do
        @controller.stubs(:restricted_email_domain).returns("@uniqlo.com")
        post :ldap
      end

      it 'does not log the user in' do
        @controller.send(:current_user).must_be_nil
      end

      it "renders" do
        assert_template :new
      end

      it "sets a flash error" do
        request.flash[:error].wont_be_nil
      end
    end
  end

  describe "#failure" do
    before do
      get :failure
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end
  end

  describe "#destroy" do
    before do
      login_as(users(:admin))
      delete :destroy
    end

    it "removes the user_id" do
      session.to_hash.except("flash").must_be_empty
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash notice" do
      request.flash[:notice].wont_be_nil
    end
  end
end
