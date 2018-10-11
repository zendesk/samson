# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 2

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
      let(:env) { {'omniauth.origin' => '/hello'} }

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
        let(:env) { {'omniauth.origin' => '/hello'} }

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
        let(:env) { {'omniauth.origin' => '/hello'} }

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
        provider: 'ldap',
        uid: '4',
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        ),
        extra: Hashie::Mash.new(
          raw_info: Hashie::Mash.new(
            sAMAccountName: [user.email]
          )
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
        let(:env) { {'omniauth.origin' => '/hello'} }

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

    describe 'with LDAP_UID as external_id' do
      it 'logs the user in' do
        Rails.application.config.samson.ldap.stub(:uid, 'sAMAccountName') do
          with_env AUTH_LDAP: 'true', USE_LDAP_UID_AS_EXTERNAL_ID: 'true' do
            post :ldap
            @controller.send(:current_user).external_id.must_equal(
              "#{strategy.name}-#{auth_hash.extra.raw_info.sAMAccountName.first}"
            )
          end
        end
      end
    end
  end

  describe "#bitbucket" do
    let(:env) { {} }
    let(:user) { users(:viewer) }
    let(:strategy) { stub(name: 'bitbucket') }
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
        post :bitbucket
      end

      it 'logs the user in' do
        @controller.send(:current_user).must_equal(user)
      end

      it 'redirects to the root path' do
        assert_redirected_to root_path
      end

      describe 'with an origin' do
        let(:env) { {'omniauth.origin' => '/hello'} }

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

  describe ".create_or_update_from_hash" do
    let(:user) { @controller.send(:find_or_create_user_from_hash, auth_hash) }

    describe "with a new user" do
      let(:auth_hash) do
        {
          name: "Test User",
          email: "test@example.org",
          role_id: Role::ADMIN.id,
          external_id: 'strange-bug'
        }
      end

      it "creates a new user" do
        user.persisted?.must_equal(true)
      end

      it "sets the role_id" do
        user.role_id.must_equal(Role::ADMIN.id)
      end

      describe "seeding" do
        before { User.delete_all }

        describe "without seeded user" do
          it "creates a super admin for the first user" do
            user.role_id.must_equal(Role::SUPER_ADMIN.id)
          end
        end

        describe "with seeded user" do
          before { User.create!(name: "Mr.Seed", email: "seed@example.com", external_id: "123") } # same as db/seed.rb

          it "creates a super admin for the first user after seeding" do
            user.role_id.must_equal(Role::SUPER_ADMIN.id)
          end

          it "does not make everybody an amdin" do
            User.create!(name: "Mr.2", email: "2@example.com", external_id: "1232")
            user.role_id.must_equal(Role::ADMIN.id)
          end
        end
      end
    end

    describe "with an existing user" do
      let(:auth_hash) do
        {
          name: "Crazy Stuff",
          email: "foobar@example.org",
          external_id: 9
        }
      end

      let!(:existing_user) { User.create!(name: "Test", external_id: 9, email: "test@example.org") }

      it "does not update the user" do
        user.name.must_equal("Test")
      end

      it "is the same user" do
        existing_user.id.must_equal(user.id)
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
