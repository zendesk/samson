require_relative '../test_helper'

describe SessionsController do
  describe "a GET to #new" do
    describe "when logged in" do
      setup do
        request.env['warden'].set_user(users(:admin))
        get :new
      end

      it "redirects to the root url" do
        assert_redirected_to root_path
      end
    end

    describe "when not logged in" do
      setup do
        get :new
      end

      it "renders" do
        assert_template :new
      end
    end
  end

  describe "a POST to #github" do
    let(:user) { users(:viewer) }
    let(:auth_hash) do
      Hashie::Mash.new(
        info: Hashie::Mash.new(
          name: user.name,
          email: user.email
        )
      )
    end

    setup do
      @controller.stubs(auth_hash: auth_hash)
      @controller.stubs(github_authorization: stub(role_id: Role::VIEWER.id))

      post :github
    end

    it 'logs the user in' do
      @controller.current_user.must_equal(user)
    end

    it 'redirects to the root path' do
      assert_redirected_to root_path
    end
  end

  describe 'a POST to #zendesk' do
    let(:user) { users(:viewer) }
    let(:email) { user.email }
    let(:role) { 'admin' }
    let(:auth_hash) do
      Hashie::Mash.new(
        info: Hashie::Mash.new(
          name: user.name,
          email: email,
          role: role
        )
      )
    end

    setup do
      @controller.stubs(auth_hash: auth_hash)
      post :zendesk
    end

    it 'redirects' do
      assert_redirected_to root_path
    end

    it 'logs the user in' do
      @controller.current_user.must_equal(user)
    end

    it 'sets the user role to DEPLOYER' do
      user.reload.role_id.must_equal(Role::ADMIN.id)
    end

    describe 'with no email' do
      let(:email) { '' }

      it 'redirects' do
        assert_redirected_to root_path
      end

      it 'does not log the user in' do
        @controller.current_user.must_be_nil
      end
    end

    describe 'with an end user' do
      let(:role) { 'end-user' }

      it 'redirects' do
        assert_redirected_to root_path
      end

      it 'does not log the user in' do
        @controller.current_user.must_be_nil
      end
    end

    describe 'with an agent' do
      let(:role) { 'agent' }

      it 'redirects' do
        assert_redirected_to root_path
      end

      it 'logs the user in' do
        @controller.current_user.must_equal(user)
      end

      it 'keeps the user role' do
        user.reload.role_id.must_equal(Role::VIEWER.id)
      end
    end
  end

  describe "a GET to #failure" do
    setup do
      get :failure
    end

    it "redirects to the root url" do
      assert_redirected_to root_path
    end

    it "sets a flash error" do
      request.flash[:error].wont_be_nil
    end
  end

  describe "a DELETE to #destroy" do
    setup do
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
